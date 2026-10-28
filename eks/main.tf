locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

data "aws_availability_zones" "available" {}

locals {
  private_subnets = [
    for i in range(length(data.aws_availability_zones.available.names)) :
    cidrsubnet(var.vpc_cidr, 6, i + 16)
  ]
  public_subnets = [
    for i in range(length(data.aws_availability_zones.available.names)) :
    cidrsubnet(var.vpc_cidr, 8, i)
  ]
}

module "vpc" {
  source = "../modules/vpc"

  name                    = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = local.public_subnets
  private_subnet_cidrs    = local.private_subnets
  karpenter_discovery_tag = local.cluster_name
  azs                     = var.azs
  tags                    = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.1"

  name               = local.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  enable_cluster_creator_admin_permissions = true
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  #Must be disabled
  endpoint_public_access = true

  #Disable auto mode
  compute_config = {
    enabled = false
  }

  addons = {
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          # Allow CoreDNS to run on the same nodes as the Karpenter controller
          # for use during cluster creation when Karpenter nodes do not yet exist
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          }
        ]
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.aws_ebs_csi_driver_role.arn
    }
  }

  eks_managed_node_groups = {
    main = {
      name           = "main-ng"
      instance_types = var.node_group_instance_types
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      desired_size   = var.node_group_desired_size
      subnet_ids     = module.vpc.private_subnet_ids
      
      taints = {
        critical_addons_only = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        name = "system-node"
      }

      block_device_mappings = {
        ebs = {
          device_name = "/dev/xvda"
          ebs = {
            encrypted  = true
            kms_key_id = aws_kms_key.ebs.arn
          }
        }
      }

      metadata_options = {
        http_put_response_hop_limit = 2
      }

    }
  }

  tags = var.tags
}

resource "aws_eks_access_entry" "devops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::326130805573:user/devops"
}

resource "aws_iam_policy" "eks_additional" {
  name        = "${local.name_prefix}-eks-additional-policy"
  description = "Additional permissions attached to the EKS cluster IAM role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      "Action" : [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ListGrants",
        "kms:DescribeKey"
      ],
      "Effect" : "Allow",
      "Resource" : aws_kms_key.ebs.arn
      }
    ]
  })

  tags = var.tags

}

#Aws load balancer controller part
resource "aws_iam_policy" "AWSLoadBalancerControllerIAMPolicy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/files/AWSLoadBalancerControllerIAMPolicy.json")
  tags   = var.tags
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.AWSLoadBalancerControllerIAMPolicy.arn
}

resource "aws_iam_role_policy_attachment" "eks_additional" {
  role       = module.eks.cluster_iam_role_name
  policy_arn = aws_iam_policy.eks_additional.arn
}

#Argocd cluster access policy
resource "aws_eks_access_policy_association" "eks-argrocd-cluster-access" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSArgoCDClusterPolicy"
  principal_arn = var.cicd_admin_role_arn

  access_scope {
    type = "cluster"
  }
}

#Access for devops user to the cluster
resource "aws_eks_access_policy_association" "eks-devops-cluster-access" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::326130805573:user/devops"

  access_scope {
    type = "cluster"
  }
}

#EBS csi driver part

resource "aws_iam_policy" "ebs_csi_driver" {
  name = "AmazonEKS_EBS_CSI_DriverPolicy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowEbsCsiDriverGrant"
        Effect = "Allow"

        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]

        Resource = aws_kms_key.ebs.arn
      },
      {
        Sid    = "AllowForEbsCsiDriverEncryption"
        Effect = "Allow"

        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]

        Resource = aws_kms_key.ebs.arn
      }
    ]
  })
}


resource "aws_iam_role" "aws_ebs_csi_driver_role" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_ebs_csi_driver_role" {
  role       = aws_iam_role.aws_ebs_csi_driver_role.name
  policy_arn = aws_iam_policy.ebs_csi_driver.arn
}

resource "aws_iam_role_policy_attachment" "eks_ebs_csi_driver_additional" {
  role       = aws_iam_role.aws_ebs_csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

#Karpenter permission and roles part
resource "aws_iam_role" "karpenter_node" {
  name = "KarpenterNodeRole-${local.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.karpenter_node.name
  policy_arn = each.value
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

resource "aws_iam_role" "karpenter_controller" {
  name = "${local.cluster_name}-karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:karpenter"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${local.cluster_name}-karpenter-controller"
  description = "Permissions for Karpenter to discover and manage EC2 capacity"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RegionalReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeCapacityReservations",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribePlacementGroups",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid      = "ReadPricingAndInstanceProfiles"
        Effect   = "Allow"
        Action   = ["pricing:GetProducts", "iam:ListInstanceProfiles"]
        Resource = "*"
      },
      {
        Sid      = "ReadSSMParameters"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/*"
      },
      {
        Sid      = "ReadInstanceProfiles"
        Effect   = "Allow"
        Action   = "iam:GetInstanceProfile"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
      },
      {
        Sid      = "DescribeCluster"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = module.eks.cluster_arn
      },
      {
        Sid      = "PassKarpenterNodeRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["ec2.amazonaws.com", "ec2.amazonaws.com.cn"]
          }
        }
      },
      {
        Sid      = "CreateKarpenterInstanceProfiles"
        Effect   = "Allow"
        Action   = "iam:CreateInstanceProfile"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                        = local.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region"               = var.aws_region
          }
          StringLike = {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid      = "TagKarpenterInstanceProfiles"
        Effect   = "Allow"
        Action   = "iam:TagInstanceProfile"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"               = var.aws_region
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}"  = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                         = local.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region"                = var.aws_region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"
          }
        }
      },
      {
        Sid    = "ManageKarpenterInstanceProfiles"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"               = var.aws_region
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "RunInstancesWithScopedNetworkResources"
        Effect = "Allow"
        Action = ["ec2:RunInstances", "ec2:CreateFleet"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}::image/*",
          "arn:aws:ec2:${var.aws_region}::snapshot/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:capacity-reservation/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:placement-group/*",
        ]
      },
      {
        Sid      = "RunInstancesWithScopedLaunchTemplates"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances", "ec2:CreateFleet"]
        Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:launch-template/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "CreateTaggedKarpenterInstances"
        Effect = "Allow"
        Action = ["ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:fleet/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:volume/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                        = local.cluster_name
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "TagCreatedKarpenterResources"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:fleet/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:volume/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:spot-instances-request/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                        = local.cluster_name
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateFleet",
              "CreateLaunchTemplate",
            ]
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid      = "TagManagedKarpenterInstances"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
          }
          StringEqualsIfExists = {
            "aws:RequestTag/eks:eks-cluster-name" = local.cluster_name
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = ["eks:eks-cluster-name", "karpenter.sh/nodeclaim", "Name"]
          }
        }
      },
      {
        Sid    = "TerminateManagedKarpenterResources"
        Effect = "Allow"
        Action = ["ec2:TerminateInstances", "ec2:RebootInstances", "ec2:DeleteLaunchTemplate"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:launch-template/*",
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

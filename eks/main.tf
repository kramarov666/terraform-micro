locals {
  name_prefix = "${var.project_name}-${var.environment}"
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

  name                 = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets
  azs                  = var.azs
  tags                 = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.1"

  name               = "${local.name_prefix}-eks"
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  enable_cluster_creator_admin_permissions = true

  #Must be disabled
  endpoint_public_access = true

  compute_config = {
    enabled = false
  }

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
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

      block_device_mappings = {
        ebs = {
          device_name = "/dev/xvda"
          ebs = {
            encrypted  = true
            kms_key_id = aws_kms_key.ebs.arn
          }
        }
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

resource "aws_iam_policy" "AWSLoadBalancerControllerIAMPolicy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/files/AWSLoadBalancerControllerIAMPolicy.json")
  tags   = var.tags
}

data "tls_certificate" "eks" {
  url = module.eks.oidc_provider_arn
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
          "${replace(module.eks.oidc_provider_arn, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(module.eks.oidc_provider_arn, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
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

resource "aws_eks_access_policy_association" "eks-argrocd-cluster-access" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSArgoCDClusterPolicy"
  principal_arn = var.cicd_admin_role_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "eks-devops-cluster-access" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::326130805573:user/devops"

  access_scope {
    type = "cluster"
  }
}


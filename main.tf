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
  source = "./modules/vpc"

  name                 = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets
  azs                  = var.azs
  tags                 = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name_prefix}-eks"
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      name           = "main-ng"
      instance_types = var.node_group_instance_types
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      desired_size   = var.node_group_desired_size

      subnet_ids = module.vpc.private_subnet_ids
    }
  }

  tags = var.tags
}

variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for resources"
  type        = string
  default     = "micro"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_group_instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "tags" {
  description = "Default resource tags"
  type        = map(string)
  default = {
    Project     = "terraform-micro"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

variable "eks_module_version" {
  description = "Version of the EKS module to use"
  type        = string
  default     = "21.24.1"
}

variable "cicd_admin_role_arn" {
  description = "ARN of the CI/CD admin role"
  type        = string
}
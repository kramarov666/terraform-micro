variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags applied to AWS resources"
  type        = map(string)
  default     = {}
}

variable "argocd_namespace" {
  description = "Namespace for ArgoCD deployment"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "10.6.4"
}

variable "argocd_repository" {
  description = "Helm repository for ArgoCD"
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_chart_name" {
  description = "Name of the ArgoCD Helm chart"
  type        = string
  default     = "argo-cd"
}

variable "argocd_deploy_name" {
  description = "Name for the ArgoCD deployment"
  type        = string
  default     = "argocd"
}

variable "k8s_git_repository" {
  description = "Git repository URL for ArgoCD application"
  type        = string
  default     = "https://github.com/argoproj/argo-cd.git"
}

variable "namespaces_git_path" {
  description = "Path in the Git repository for namespaces"
  type        = string
  default     = "namespaces"
}

variable "k8s_git_repository_ssh_private_key" {
  description = "SSH private key used by Argo CD to access the Git repository"
  type        = string
  sensitive   = true
}
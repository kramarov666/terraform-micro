data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "prod-tfstate-bucket-326130805573-us-east-1"
    key    = "terraform-micro/eks/terraform.tfstate"
    region = var.aws_region
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks_cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.terraform_remote_state.eks.outputs.eks_cluster_name
      ]
    }
  }
}

resource "helm_release" "argocd" {
  name             = var.argocd_deploy_name
  repository       = var.argocd_repository
  chart            = var.argocd_chart_name
  namespace        = var.argocd_namespace
  create_namespace = true
  version          = var.argocd_chart_version

  #values = [
  #  file("${path.module}/values/argocd.yaml")
  #]
}

resource "null_resource" "kubernetes_manifest" {
  depends_on = [
    helm_release.argocd
  ]

  triggers = {
    cluster_name = data.terraform_remote_state.eks.outputs.eks_cluster_name

    manifest_hash = filesha256(
      "${path.module}/manifests/argocd/apps.yaml"
    )
    repo_secret_hash = sha256(var.k8s_git_repository_ssh_private_key)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    working_dir = "${path.module}/manifests/argocd"

    command = <<-EOT
      set -e

      aws eks update-kubeconfig \
        --name '${data.terraform_remote_state.eks.outputs.eks_cluster_name}' \
        --region '${var.aws_region}'

      kubectl apply -f apps.yaml -f secrets.yaml
    EOT
  }
}
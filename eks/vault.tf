resource "aws_iam_role" "vault_unseal" {
  name = "${local.name_prefix}-vault-unseal"

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
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:vault:vault"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "vault_unseal" {
  name        = "${local.name_prefix}-vault-unseal"
  description = "Allow Vault to use its KMS auto-unseal key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
      ]
      Resource = var.vault_unseal_kms_key_arn
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vault_unseal" {
  role       = aws_iam_role.vault_unseal.name
  policy_arn = aws_iam_policy.vault_unseal.arn
}

resource "aws_iam_role" "vault_backup_recovery" {
  name = "${local.name_prefix}-vault-backup-recovery"

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
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:vault:vault-backup-recovery"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "vault_backup_recovery" {
  name        = "${local.name_prefix}-vault-backup-recovery"
  description = "Allow Vault backup recovery to read and write backups in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.vault_backup_s3_bucket}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "arn:aws:s3:::${var.vault_backup_s3_bucket}/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vault_backup_recovery" {
  role       = aws_iam_role.vault_backup_recovery.name
  policy_arn = aws_iam_policy.vault_backup_recovery.arn
}

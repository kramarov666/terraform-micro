# resource "aws_iam_role" "vault_unseal" {
#   name = "${local.name_prefix}-vault-unseal"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = "sts:AssumeRoleWithWebIdentity"
#       Principal = {
#         Federated = module.eks.oidc_provider_arn
#       }
#       Condition = {
#         StringEquals = {
#           "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
#           "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:vault:vault"
#         }
#       }
#     }]
#   })

#   tags = var.tags
# }

# resource "aws_iam_policy" "vault_unseal" {
#   name        = "${local.name_prefix}-vault-unseal"
#   description = "Allow Vault to use its KMS auto-unseal key"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = [
#         "kms:Decrypt",
#         "kms:DescribeKey",
#         "kms:Encrypt",
#       ]
#       Resource = aws_kms_key.vault_unseal.arn
#     }]
#   })

#   tags = var.tags
# }

# resource "aws_iam_role_policy_attachment" "vault_unseal" {
#   role       = aws_iam_role.vault_unseal.name
#   policy_arn = aws_iam_policy.vault_unseal.arn
# }

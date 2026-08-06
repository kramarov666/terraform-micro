data "aws_caller_identity" "current" {}

resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption in ${var.project_name}-${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ebs-kms"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.project_name}-${var.environment}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_kms_key_policy" "ebs" {
  key_id = aws_kms_key.ebs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEC2Service"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]

        Resource = "*"

      }
    ]
  })
}

#resource "aws_kms_key_policy" "ebs" {
#  key_id = aws_kms_key.ebs.id
#  policy = jsonencode({
#    "Version" : "2012-10-17",
#    "Id" : "MyKeyPolicy",
#    "Statement" : [
#      {
#        "Sid" : "Enable Root Permissions",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
#        },
#        "Action" : "kms:*",
#        "Resource" : "*"
#      },
#      {
#        "Sid" : "Allow use of the key",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : [
#            module.eks.cluster_iam_role_arn
#          ]
#        },
#        "Action" : [
#          "kms:Encrypt",
#          "kms:Decrypt",
#          "kms:ReEncrypt*",
#          "kms:GenerateDataKey*",
#          "kms:DescribeKey"
#        ],
#        "Resource" : "*"
#      },
#      {
#        "Sid" : "Allow attachment of persistent resources",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : [
#            module.eks.cluster_iam_role_arn
#          ]
#        },
#        "Action" : [
#          "kms:CreateGrant",
#          "kms:ListGrants",
#          "kms:RevokeGrant"
#        ],
#        "Resource" : "*",
#        "Condition" : {
#          "Bool" : {
#            "kms:GrantIsForAWSResource" : "true"
#          }
#        }
#      },
#      {
#        "Sid" : "Allow EBS service to use the key",
#        "Effect" : "Allow",
#        "Principal" : {
#          "Service" : "ec2.amazonaws.com"
#        },
#        "Action" : [
#          "kms:Encrypt",
#          "kms:Decrypt",
#          "kms:ReEncrypt*",
#          "kms:GenerateDataKey*",
#          "kms:DescribeKey",
#          "kms:CreateGrant",
#          "kms:ListGrants",
#          "kms:RevokeGrant"
#        ],
#        "Resource" : "*",
#        "Condition" : {
#          "Bool" : {
#            "kms:GrantIsForAWSResource" : "true"
#          }
#        }
#      }
#    ]
#  })
#}

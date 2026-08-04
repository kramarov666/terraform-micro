# Terraform Micro

This project provisions an AWS VPC and an EKS cluster using:

- a custom VPC module under `modules/vpc`
- the public Terraform AWS EKS module from the registry
- an S3 backend for Terraform state

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with an account and region
- IAM permissions to create VPC, EKS, IAM roles, and S3/DynamoDB state resources

## S3 backend setup

Create an S3 bucket and DynamoDB lock table first:

```bash
aws s3 mb s3://my-terraform-state-bucket --region us-east-1
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

Then copy the backend example and update the values:

```bash
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` with your bucket name, key, region, and DynamoDB table.

## Initialize and apply

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Destroy

```bash
terraform destroy
```

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

terraform {
  backend "s3" {
    bucket = "huykal-us-east-1"
    key    = "terraform-micro/terraform.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.57"
    }
  }
}

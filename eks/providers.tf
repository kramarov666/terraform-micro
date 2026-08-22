provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

terraform {
  backend "s3" {
    bucket = "prod-tfstate-bucket-326130805573-us-east-1"
    key    = "terraform-micro/terraform.tfstate"
    region = "us-east-1"
  }

}

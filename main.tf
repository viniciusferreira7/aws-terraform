terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }


  }
  backend "s3" {
    bucket = "aws-terraform-s3"
    key    = "state/terraform.tfstate"
    region = var.region
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "aws-terraform"
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    IAC = "True"
  }
}

resource "aws_s3_bucket_acl" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "versioning_terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

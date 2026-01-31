terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # backend "s3" {
  #   bucket = "aws-terraform-vinicius-study"
  #   key    = "state/terraform.tfstate"
  #   region = "us-east-1"
  # }
}


provider "aws" {
  region  = var.region
  profile = var.profile
}


locals {
  state_bucket_name = "aws-terraform-vinicius-study"
  common_tags = {
    IAC     = "True"
    Project = "Terraform Study"
  }
}


resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.state_bucket_name
  force_destroy = true

  tags = local.common_tags
}


resource "aws_s3_bucket_versioning" "versioning_terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}
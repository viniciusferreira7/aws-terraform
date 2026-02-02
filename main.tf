terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "aws-terraform-vinicius-study"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_instance" "aws_terraform_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = local.common_tags
}
# AWS Terraform Study

**Status:** 🚧 Work in Progress

This project is used to create and manage AWS resources with Terraform for study and learning purposes.

## Resources

This project creates the following AWS resources:

- **S3 Bucket** - For storing Terraform state with versioning enabled
- **S3 Backend** - Remote state management

## Files

- `main.tf` - Main Terraform configuration with provider setup and S3 bucket resources
- `variables.tf` - Variable definitions for AWS profile and region
- `terraform.tfvars` - Variable values (not tracked in git)
- `.gitignore` - Terraform-specific files to ignore

## Usage

1. Configure your AWS credentials
2. Set variables in `terraform.tfvars`:
   ```hcl
   profile = "your-aws-profile"
   region  = "us-east-1"
   ```
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Apply the configuration:
   ```bash
   terraform apply
   ```

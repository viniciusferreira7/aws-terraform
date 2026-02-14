# ACM Certificate for HTTPS (optional)
# Uncomment and configure this section if you want to use a custom domain with HTTPS

# variable "domain_name" {
#   type        = string
#   description = "Domain name for ACM certificate"
#   # Example: "example.com"
# }

# resource "aws_acm_certificate" "app" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"
#
#   subject_alternative_names = [
#     "*.${var.domain_name}"
#   ]
#
#   lifecycle {
#     create_before_destroy = true
#   }
#
#   tags = local.common_tags
# }

# DNS Validation Records
# Note: You'll need to add these records to your DNS provider (Route 53, CloudFlare, etc.)

# resource "aws_acm_certificate_validation" "app" {
#   certificate_arn = aws_acm_certificate.app.arn
# }

# Outputs
# output "certificate_arn" {
#   description = "ARN of the ACM certificate"
#   value       = aws_acm_certificate.app.arn
# }

# output "certificate_validation_records" {
#   description = "DNS validation records for the certificate"
#   value       = aws_acm_certificate.app.domain_validation_options
# }

# MANUAL ALTERNATIVE:
# Instead of managing the certificate in Terraform, you can:
# 1. Request a certificate manually in the AWS Console
# 2. Complete DNS validation
# 3. Pass the certificate ARN via the certificate_arn variable
#
# Example:
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"

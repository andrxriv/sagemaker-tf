# ==============================================================================
# SageMaker Infrastructure with Terraform
# ==============================================================================
# This file orchestrates the creation of AWS SageMaker infrastructure including:
# - VPC and networking components
# - SageMaker Domain with JupyterLab support
# - EFS shared file system
# - IAM roles and policies
# - Security groups and KMS encryption
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================================================
# Local Values
# ==============================================================================

locals {
  # Environment configuration
  environment = var.env
  region      = "us-east-1"
  
  # Resource naming
  name_prefix = "infra-test"
  
  # Common tags applied to all resources
  common_tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      "Project"     = "SageMaker Infrastructure"
      "Environment" = local.environment
      "ManagedBy"   = "Terraform"
      "CreatedDate" = timestamp()
    }
  )
}

# ==============================================================================
# Data Sources
# ==============================================================================

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ==============================================================================
# VPC and Networking Infrastructure
# ==============================================================================
# Resources defined in: vpc.tf
# - Application VPC with public/private subnets
# - Internet Gateway and NAT Gateways
# - Route tables and associations
# - VPC Endpoints for SageMaker and S3

# ==============================================================================
# SageMaker Infrastructure
# ==============================================================================
# Resources defined in: sagemaker.tf
# - IAM execution role with comprehensive policies
# - Security groups for SageMaker applications
# - KMS key for EFS encryption
# - EFS file system with access points
# - SageMaker Domain configuration
# - All required IAM policy attachments

# ==============================================================================
# Outputs
# ==============================================================================

output "vpc_info" {
  description = "VPC infrastructure information"
  value = {
    vpc_id             = aws_vpc.application_vpc.id
    private_subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    public_subnet_ids  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  }
}

output "sagemaker_info" {
  description = "SageMaker infrastructure information"
  value = {
    domain_id          = aws_sagemaker_domain.jupyterlab_domain.id
    domain_arn         = aws_sagemaker_domain.jupyterlab_domain.arn
    domain_name        = aws_sagemaker_domain.jupyterlab_domain.domain_name
    execution_role_arn = aws_iam_role.sagemaker_jupyterlab_execution_role.arn
    security_group_id  = aws_security_group.sagemaker_jupyterlab_sg.id
  }
}

output "efs_info" {
  description = "EFS file system information"
  value = {
    file_system_id  = aws_efs_file_system.shared_efs.id
    file_system_arn = aws_efs_file_system.shared_efs.arn
    access_point_id = aws_efs_access_point.shared_repo_ap.id
    kms_key_id      = aws_kms_key.efs_kms.id
    kms_key_alias   = aws_kms_alias.efs_kms_alias.name
  }
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    region              = data.aws_region.current.name
    account_id          = data.aws_caller_identity.current.account_id
    environment         = local.environment
    deployment_time     = timestamp()
    terraform_workspace = terraform.workspace
  }
}

# ==============================================================================
# Deployment Instructions
# ==============================================================================
# 
# To deploy this infrastructure:
# 
# 1. Development Environment:
#    terraform init
#    terraform plan
#    terraform apply
# 
# 2. Production Environment:
#    terraform init
#    terraform plan -var-file="prod.tfvars"
#    terraform apply -var-file="prod.tfvars"
# 
# 3. Cleanup:
#    terraform destroy
#    # or for production:
#    terraform destroy -var-file="prod.tfvars"
# 
# ==============================================================================

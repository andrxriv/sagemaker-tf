# Environment and Account Configuration
variable "name" {
  description = "Base name for the infrastructure deployment"
  type        = string
  default     = "terraform-infra-deployment"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS Region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "211125392873"
}

# S3 Bucket Variables
variable "account_sagemaker_bucket" {
  description = "S3 bucket for SageMaker account resources"
  type        = string
  default     = "account-sagemaker_andrxriv"
}

variable "studio_sharing_bucket" {
  description = "S3 bucket for Studio sharing resources"
  type        = string
  default     = "studio-sharing_andrxriv"
}

variable "rstudio_domain_bucket" {
  description = "S3 bucket for RStudio domain resources"
  type        = string
  default     = "rstudio-domain_andrxriv"
}

variable "shared_analytics_bucket" {
  description = "S3 bucket for shared analytics resources"
  type        = string
  default     = "shared-analytics_andrxriv"
}

variable "sharable_notebook_resource" {
  description = "S3 bucket for sharable notebook resources"
  type        = string
  default     = "sharable-notebook-resource_andrxriv"
}

# Tag Variables
variable "overall_tags" {
  description = "Overall tags to apply to all resources"
  type        = map(string)
  default = {
    auto-delete = "no"
  }
}

variable "environment_tags" {
  description = "Environment-specific tags"
  type        = map(string)
  default = {
    env = "dev"
  }
}

variable "security_group_tags" {
  description = "Security group specific tags"
  type        = map(string)
  default = {
    name = "sagemaker-tf-sg"
  }
}

variable "iam_role_tags" {
  description = "Tags for IAM roles"
  type        = map(string)
  default = {
    auto-delete = "no"
    env         = "dev"
  }
}

# Space Configuration
variable "space_owner_profile_name" {
  description = "Owner user profile name for the shared space"
  type        = string
  default     = "andrxriv-19c"
}

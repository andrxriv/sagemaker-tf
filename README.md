# SageMaker Infrastructure with Terraform

A comprehensive Terraform project for deploying Amazon SageMaker infrastructure including VPC, domain configuration, EFS shared storage, and IAM security policies.

## Overview

This project creates a complete SageMaker Studio environment with:

- **VPC Infrastructure**: Custom VPC with public/private subnets, NAT gateways, and VPC endpoints
- **SageMaker Domain**: Full-featured SageMaker Studio domain with JupyterLab support
- **Shared Storage**: Encrypted EFS file system for team collaboration
- **Security**: Comprehensive IAM roles, policies, and security groups
- **Networking**: Optimized networking with VPC endpoints for SageMaker and S3

## Architecture

![SageMaker Infrastructure Architecture](./architecture.svg)

### Components

1. **Networking (vpc.tf)**
   - Application VPC with multi-AZ deployment
   - Public and private subnets
   - Internet Gateway and NAT Gateways
   - VPC Endpoints for SageMaker API, SageMaker Runtime, and S3

2. **SageMaker Infrastructure (sagemaker.tf)**
   - IAM execution role with comprehensive permissions
   - SageMaker Domain with SSO authentication
   - Security groups for applications and EFS
   - KMS encryption for EFS
   - EFS file system with access points

3. **Configuration (main.tf)**
   - Terraform requirements and provider configuration
   - Local values and data sources
   - Comprehensive outputs

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- AWS Account with SageMaker permissions

## Deployment

### Development Environment

```bash
terraform init
terraform plan
terraform apply
```

### Production Environment

```bash
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Configuration

### Variables

Key variables defined in `variables.tf`:

- `env` - Environment name (dev/prod)
- `account_id` - AWS Account ID
- S3 bucket configurations
- Tagging strategy

### Environments

- **Development**: Uses default variables
- **Production**: Uses `prod.tfvars` for production-specific configuration

## Features

### SageMaker Studio Configuration

- **Authentication**: AWS SSO (Identity Center)
- **Network**: VPC-only access for security
- **Applications**: All SageMaker Studio applications available
- **Lifecycle Management**: Automatic idle timeout configuration
- **Shared Storage**: EFS mounted at `/shared_repo`

### Security Features

- KMS encryption for EFS storage
- Least privilege IAM policies
- Security groups with minimal required access
- VPC endpoints for private communication

### Collaboration Features

- Shared EFS file system for team collaboration
- Notebook sharing capabilities
- Common execution role for consistent permissions

## Outputs

After deployment, the following information is available:

- **VPC Info**: VPC ID and subnet information
- **SageMaker Info**: Domain details and execution role
- **EFS Info**: File system and encryption details
- **Deployment Info**: Environment and timing information

## Cleanup

To destroy all resources:

```bash
terraform destroy
# or for production:
terraform destroy -var-file="prod.tfvars"
```

## File Structure

```
├── main.tf          # Main orchestration and outputs
├── provider.tf      # AWS provider configuration
├── variables.tf     # Variable definitions
├── vpc.tf          # VPC and networking resources
├── sagemaker.tf    # SageMaker domain and related resources
├── prod.tfvars     # Production environment variables (ignored by git)
├── .gitignore      # Git ignore rules
└── README.md       # This file
```

## Notes

- The `.gitignore` file excludes sensitive files like `*.tfvars`, `*.tfstate`, and `.terraform/`
- Production variables should be managed securely and not committed to version control
- The infrastructure supports both development and production deployments
- All resources are tagged consistently for cost allocation and management
- In order to effectively use the custom EFS file system, a bastion instance will be required to set ownership of the EFS to 2000001:1001

## Support

For issues or questions about this infrastructure, please refer to the AWS SageMaker documentation or create an issue in this repository.

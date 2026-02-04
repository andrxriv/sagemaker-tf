# ==============================================================================
# EFS (Elastic File System) Configuration for SageMaker Shared Storage
# ==============================================================================

# ---------------------------------------------------------------------------
# KMS key for EFS encryption 
# ---------------------------------------------------------------------------
resource "aws_kms_key" "efs_kms" {
  description             = "KMS for SageMaker shared EFS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SageMaker to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "elasticfilesystem.${var.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow SageMaker execution role to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.sagemaker_jupyterlab_execution_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EFS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "elasticfilesystem.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(var.overall_tags, var.environment_tags, { Name = "sagemaker-efs-kms" })
}

resource "aws_kms_alias" "efs_kms_alias" {
  name          = "alias/sagemaker-efs"
  target_key_id = aws_kms_key.efs_kms.key_id
}

# ---------------------------------------------------------------------------
# Security Group for EFS mount targets
# Allows NFS (2049/TCP) from SageMaker apps security group
# ---------------------------------------------------------------------------
resource "aws_security_group" "efs_nfs_sg" {
  name        = "infra-test-efs-nfs-sg-${var.env}"
  description = "Allow NFS from SageMaker apps"
  vpc_id      = aws_vpc.application_vpc.id
  
  ingress {
    description     = "NFS from SageMaker apps"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.sagemaker_jupyterlab_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.overall_tags, var.environment_tags, { Name = "efs-nfs" })
}

# ---------------------------------------------------------------------------
# EFS file system (encrypted with customer managed KMS key)
# ---------------------------------------------------------------------------
resource "aws_efs_file_system" "shared_efs" {
  encrypted        = true
  kms_key_id       = aws_kms_key.efs_kms.arn
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  
  tags = merge(var.overall_tags, var.environment_tags, { Name = "sagemaker-shared-efs-${var.env}" })
}

# ---------------------------------------------------------------------------
# Access point for shared repository with SageMaker-compatible UID/GID
# Studio apps default to UID=200001, GID=1001
# ---------------------------------------------------------------------------
resource "aws_efs_access_point" "shared_repo_ap" {
  file_system_id = aws_efs_file_system.shared_efs.id

  root_directory {
    path = "/"
    creation_info {
      owner_uid   = 200001
      owner_gid   = 1001
      permissions = "777"
    }
  }

  posix_user {
    uid = 200001
    gid = 1001
  }

  tags = merge(var.overall_tags, var.environment_tags, { Name = "shared-repo-ap" })
}

# ---------------------------------------------------------------------------
# Mount targets in private subnets used by SageMaker Domain
# Required: mount target per subnet associated with the Domain
# ---------------------------------------------------------------------------
resource "aws_efs_mount_target" "shared_efs_mt_1" {
  file_system_id  = aws_efs_file_system.shared_efs.id
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.efs_nfs_sg.id]
}

resource "aws_efs_mount_target" "shared_efs_mt_2" {
  file_system_id  = aws_efs_file_system.shared_efs.id
  subnet_id       = aws_subnet.private_subnet_2.id
  security_groups = [aws_security_group.efs_nfs_sg.id]
}

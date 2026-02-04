resource "aws_iam_role" "sagemaker_jupyterlab_execution_role" {
  name = "infra-test-sagemaker-jupyterlab-execution-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "sagemaker.amazonaws.com"
        },
        Action = "sts:AssumeRole",
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:sagemaker:${var.region}:${var.account_id}:*"
          }
        }
      }
    ]
  })

  tags = var.iam_role_tags
}

resource "aws_iam_role_policy_attachment" "canvas_ai_services_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerCanvasAIServicesAccess"
}

resource "aws_iam_role_policy_attachment" "canvas_dataprep_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerCanvasDataPrepFullAccess"
}

resource "aws_iam_role_policy_attachment" "canvas_directdeploy_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSageMakerCanvasDirectDeployAccess"
}

resource "aws_iam_role_policy_attachment" "canvas_fullaccess_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerCanvasFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_fullaccess_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}


resource "aws_iam_policy" "jupyterlab_license_cloudwatch" {
  name        = "infra-test-JupyterLab-license-cloudwatch-${var.env}"
  description = "Allows JupyterLab to access CloudWatch Logs and AWS License Manager"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "VisualEditor0",
        Effect = "Allow",
        Action = [
          "license-manager:ExtendLicenseConsumption",
          "license-manager:ListReceivedLicenses",
          "license-manager:GetLicense",
          "license-manager:CheckoutLicense",
          "license-manager:CheckInLicense",
          "logs:CreateLogDelivery",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DeleteLogDelivery",
          "logs:Describe*",
          "logs:GetLogDelivery",
          "logs:GetLogEvents",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:UpdateLogDelivery",
          "sagemaker:CreateApp"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jupyterlab_license_cloudwatch_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = aws_iam_policy.jupyterlab_license_cloudwatch.arn
}


resource "aws_iam_policy" "jupyterlab_s3_access" {
  name        = "infra-test-JupyterLab-S3AccessPolicy"
  description = "Allows JupyterLab to access specific S3 buckets for reading, writing, and listing objects"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.account_sagemaker_bucket}/*",
          "arn:aws:s3:::${var.studio_sharing_bucket}/sharing/*",
          "arn:aws:s3:::${var.rstudio_domain_bucket}/*",
          "arn:aws:s3:::${var.shared_analytics_bucket}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.account_sagemaker_bucket}/*",
          "arn:aws:s3:::${var.studio_sharing_bucket}/sharing/*",
          "arn:aws:s3:::${var.rstudio_domain_bucket}/*",
          "arn:aws:s3:::${var.shared_analytics_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jupyterlab_s3_access_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = aws_iam_policy.jupyterlab_s3_access.arn
}


resource "aws_iam_policy" "jupyterlab_common_job_management" {
  name        = "infra-test-JupyterLab-CommonJobManagementPolicy-${var.env}"
  description = "Allows JupyterLab to manage SageMaker training, processing, and AutoML jobs, and pass roles"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:CreateTransformJob",
          "sagemaker:CreateProcessingJob",
          "sagemaker:CreateAutoMLJob",
          "sagemaker:CreateHyperParameterTuningJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:StopProcessingJob",
          "sagemaker:StopAutoMLJob",
          "sagemaker:StopHyperParameterTuningJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:DescribeTransformJob",
          "sagemaker:DescribeProcessingJob",
          "sagemaker:DescribeAutoMLJob",
          "sagemaker:DescribeHyperParameterTuningJob",
          "sagemaker:UpdateTrainingJob",
          "sagemaker:BatchGetMetrics"
        ],
        Resource = "arn:aws:sagemaker:*:*:*/*"
      },
      {
        Effect = "Allow",
        Action = [
          "sagemaker:Search",
          "sagemaker:ListTrainingJobs",
          "sagemaker:ListTransformJobs",
          "sagemaker:ListProcessingJobs",
          "sagemaker:ListAutoMLJobs",
          "sagemaker:ListCandidatesForAutoMLJob",
          "sagemaker:ListHyperParameterTuningJobs",
          "sagemaker:ListTrainingJobsForHyperParameterTuningJob"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          "arn:aws:iam::${var.account_id}:role/infra-test-sagemaker-jupyterlab-execution-role-${var.env}"
        ],
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      },
      {
        # description = "Policy to manage SageMaker MLflow Tracking Server for JupyterLab"
        # Sid    = "MLFlowManagementComprehensive",
        Effect = "Allow",
        Action = [
          "sagemaker:DeleteMlflowTrackingServer",
          "sagemaker:DescribeMlflowTrackingServer",
          "sagemaker:StartMlflowTrackingServer",
          "sagemaker:StopMlflowTrackingServer",
          "sagemaker:UpdateMlflowTrackingServer"
        ],
        Resource = "arn:aws:sagemaker:${var.region}:${var.account_id}:mlflow-tracking-server/*"
      },
      {
        # Sid    = "MLFlowManagementTagOnCreate",
        Effect = "Allow",
        Action = "sagemaker:AddTags",
        Resource = "arn:aws:sagemaker:${var.region}:${var.account_id}:mlflow-tracking-server/*",
        Condition = {
          Null = {
            "sagemaker:TaggingAction" = "false"
          }
        }
      },
      {
        # Sid    = "MLFlowManagementCreateAndList",
        Effect = "Allow",
        Action = [
          "sagemaker:CreateMlflowTrackingServer",
          "sagemaker:CreatePresignedMlflowTrackingServerUrl",
          "sagemaker:ListMlflowTrackingServers"
        ],
        Resource = "*"
      },
      {
        # description = "Policy to allow access to SageMaker MLflow Tracking Server for JupyterLab"
        # Sid    = "MLFLowPermissionsDescribeAndListTags",
        Effect = "Allow",
        Action = [
          "sagemaker:DescribeMlflowTrackingServer",
          "sagemaker:ListTags"
        ],
        Resource = "arn:aws:sagemaker:${var.region}:${var.account_id}:mlflow-tracking-server/*"
      },
      {
        # Sid    = "MLFLowPermissionsCreatePresignedUrlAndListServers",
        Effect = "Allow",
        Action = [
          "sagemaker:CreatePresignedMlflowTrackingServerUrl",
          "sagemaker:ListMlflowTrackingServers"
        ],
        Resource = "*"
      },
      {
        # Sid    = "MLFLowPermissionsComprehensive",
        Effect = "Allow",
        Action = [
          "sagemaker-mlflow:*"
        ],
        Resource = "arn:aws:sagemaker:${var.region}:${var.account_id}:mlflow-tracking-server/*"
      },
      {
        # Sid    = "MLFlowTrackingExecutionBucketPermissions",
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetBucketCors",
          "s3:PutBucketCors"
        ],
        Resource = [
          "arn:aws:s3:::sagemaker-*",
          "arn:aws:s3:::sagemaker-*/*"
        ],
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = "${var.account_id}"
          }
        }
      },
      {
        # Sid    = "MLFlowTrackingExecutionModelRegistry",
        Effect = "Allow",
        Action = [
          "sagemaker:CreateModelPackage",
          "sagemaker:CreateModelPackageGroup",
          "sagemaker:UpdateModelPackage"
        ],
        Resource = "arn:aws:sagemaker:${var.region}:${var.account_id}:*/*"
      },
      {
        # Sid    = "MLFlowTrackingExecutionModelRegistryAddTags",
        Effect = "Allow",
        Action = "sagemaker:AddTags",
        Resource = [
          "arn:aws:sagemaker:${var.region}:${var.account_id}:model-package/*",
          "arn:aws:sagemaker:${var.region}:${var.account_id}:model-package-group/*"
        ],
        Condition = {
          Null = {
            "sagemaker:TaggingAction" = "false"
          }
        }
      },
      {
        # Sid    = "MLFlowTrackingExecutionListTags",
        Effect = "Allow",
        Action = "sagemaker:ListTags",
        Resource = "arn:aws:sagemaker:${var.region}:${var.account_id}:mlflow-tracking-server/*"
      },
      {
        # description = "Policy for managing models in SageMaker JupyterLab"
        Effect = "Allow",
        Action = [
          "sagemaker:CreateModel",
          "sagemaker:CreateModelPackage",
          "sagemaker:CreateModelPackageGroup",
          "sagemaker:DescribeModel",
          "sagemaker:DescribeModelPackage",
          "sagemaker:DescribeModelPackageGroup",
          "sagemaker:BatchDescribeModelPackage",
          "sagemaker:UpdateModelPackage",
          "sagemaker:DeleteModel",
          "sagemaker:DeleteModelPackage",
          "sagemaker:DeleteModelPackageGroup"
        ],
        Resource = "arn:aws:sagemaker:*:*:*/*"
      },
      {
        Effect = "Allow",
        Action = [
          "sagemaker:ListModels",
          "sagemaker:ListModelPackages",
          "sagemaker:ListModelPackageGroups"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          "arn:aws:iam::${var.account_id}:role/infra-test-sagemaker-jupyterlab-execution-role-${var.env}"
        ],
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "sagemaker.amazonaws.com"
          }
        }
      },
      {
        # name   = "AmazonQDeveloperPolicy"
        Effect   = "Allow",
        Action   = ["q:SendMessage"],
        Resource = ["*"]
      },
      {
        Sid      = "AmazonQDeveloperPermissions",
        Effect   = "Allow",
        Action   = ["codewhisperer:GenerateRecommendations"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jupyterlab_common_job_management_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = aws_iam_policy.jupyterlab_common_job_management.arn
}


resource "aws_iam_policy" "jupyterlab_efs_access" {
  name        = "infra-test-JupyterLab-EFSAccessPolicy-${var.env}"
  description = "Allows JupyterLab to access the shared EFS file system"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess",
          "elasticfilesystem:DescribeMountTargets"
        ],
        Resource = "arn:aws:elasticfilesystem:${var.region}:${var.account_id}:file-system/${aws_efs_file_system.shared_efs.id}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jupyterlab_efs_access_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = aws_iam_policy.jupyterlab_efs_access.arn
}

data "aws_iam_policy" "sm_studio_app_permissions_jupyterlab" {
  name = "SM_StudioAppPermissions_jupyterlab"
}

resource "aws_iam_role_policy_attachment" "studio_app_permissions_attachment" {
  role       = aws_iam_role.sagemaker_jupyterlab_execution_role.name
  policy_arn = data.aws_iam_policy.sm_studio_app_permissions_jupyterlab.arn
}


resource "aws_security_group" "sagemaker_jupyterlab_sg" {
  name        = "infra-test-sagemaker-jupyterlab-sg-${var.env}"
  description = "Security group for SageMaker JupyterLab"
  vpc_id      = aws_vpc.application_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_sagemaker_domain" "jupyterlab_domain" {
  domain_name = "${var.name}-${var.env}"

  auth_mode                       = "SSO"  # AWS Identity Center
  app_network_access_type        = "VpcOnly"
  app_security_group_management  = "Service"
  subnet_ids                     = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  vpc_id                         = aws_vpc.application_vpc.id
  tag_propagation                = "ENABLED"
  
  # Ensure EFS mount targets are ready before domain update
  depends_on = [aws_efs_mount_target.shared_efs_mt_1, aws_efs_mount_target.shared_efs_mt_2]
  
  domain_settings {
    security_group_ids = [aws_security_group.sagemaker_jupyterlab_sg.id]
  }

  default_user_settings {
    execution_role      = aws_iam_role.sagemaker_jupyterlab_execution_role.arn
    auto_mount_home_efs = "Enabled"
    
    # Mount the shared EFS file system to all users in the domain
    custom_file_system_config {
        efs_file_system_config {
          file_system_id   = aws_efs_file_system.shared_efs.id
          file_system_path = "/"
        }
      }
    
    
    jupyter_lab_app_settings {
      app_lifecycle_management {
        idle_settings {
          lifecycle_management        = "ENABLED"
          idle_timeout_in_minutes     = 120
          max_idle_timeout_in_minutes = 480
          min_idle_timeout_in_minutes = 60
        }
      }
    }
    
    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://${var.sharable_notebook_resource}/sharing"
    }
    
    studio_web_portal_settings {
      hidden_instance_types = [
        "ml.t3.medium", "ml.t3.large", "ml.t3.xlarge", "ml.m5.large", "ml.m5.2xlarge", "ml.m5.4xlarge", "ml.m5.8xlarge", "ml.m5.12xlarge",
        "ml.m5.16xlarge", "ml.m5.24xlarge", "ml.m5d.large", "ml.m5d.2xlarge", "ml.m5d.4xlarge", "ml.m5d.8xlarge", "ml.m5d.12xlarge",
        "ml.m5d.16xlarge", "ml.m5d.24xlarge", "ml.m6i.large", "ml.m6i.2xlarge", "ml.m6i.4xlarge", "ml.m6i.8xlarge", "ml.m6i.12xlarge",
        "ml.m6i.16xlarge", "ml.m6i.24xlarge", "ml.m6i.32xlarge", "ml.m6id.large", "ml.m6id.xlarge", "ml.m6id.2xlarge", "ml.m6id.4xlarge",
        "ml.m6id.8xlarge", "ml.m6id.12xlarge", "ml.m6id.16xlarge", "ml.m6id.24xlarge", "ml.m6id.32xlarge", "ml.m7i.large", "ml.m7i.xlarge", 
        "ml.m7i.2xlarge", "ml.m7i.4xlarge", "ml.m7i.8xlarge", "ml.m7i.12xlarge", "ml.m7i.16xlarge", "ml.m7i.24xlarge", "ml.m7i.48xlarge",
        "ml.c5.large", "ml.c5.xlarge", "ml.c5.2xlarge", "ml.c5.4xlarge", "ml.c5.9xlarge", "ml.c5.12xlarge", "ml.c5.18xlarge", "ml.c5.24xlarge",
        "ml.c6i.large", "ml.c6i.2xlarge", "ml.c6i.4xlarge", "ml.c6i.8xlarge", "ml.c6i.12xlarge", "ml.c6i.16xlarge", "ml.c6i.24xlarge", "ml.c6i.32xlarge",
        "ml.c6id.large", "ml.c6id.2xlarge", "ml.c6id.4xlarge", "ml.c6id.8xlarge", "ml.c6id.12xlarge", "ml.c6id.16xlarge", "ml.c6id.24xlarge", "ml.c6id.32xlarge",
        "ml.c7i.large", "ml.c7i.xlarge", "ml.c7i.2xlarge", "ml.c7i.4xlarge", "ml.c7i.8xlarge", "ml.c7i.12xlarge", "ml.c7i.16xlarge", "ml.c7i.24xlarge",
        "ml.c7i.48xlarge", "ml.r5.large", "ml.r5.xlarge", "ml.r5.2xlarge", "ml.r5.4xlarge", "ml.r5.8xlarge", "ml.r5.12xlarge", "ml.r5.16xlarge", "ml.r5.24xlarge",
        "ml.r6i.large", "ml.r6i.2xlarge", "ml.r6i.4xlarge", "ml.r6i.8xlarge", "ml.r6i.12xlarge", "ml.r6i.16xlarge", "ml.r6i.24xlarge", "ml.r6i.32xlarge",
        "ml.r6id.2xlarge", "ml.r6id.4xlarge", "ml.r6id.8xlarge", "ml.r6id.12xlarge", "ml.r6id.16xlarge", "ml.r6id.24xlarge", "ml.r6id.32xlarge",
        "ml.r7i.large", "ml.r7i.xlarge", "ml.r7i.2xlarge", "ml.r7i.4xlarge", "ml.r7i.8xlarge", "ml.r7i.12xlarge", "ml.r7i.24xlarge", "ml.r7i.48xlarge",
        "ml.p3.8xlarge", "ml.p3.2xlarge", "ml.p3.16xlarge", "ml.p4d.24xlarge", "ml.g4dn.2xlarge", "ml.g4dn.4xlarge", "ml.g4dn.8xlarge", "ml.g4dn.12xlarge", "ml.g4dn.16xlarge",
        "ml.g5.xlarge", "ml.g5.2xlarge", "ml.g5.4xlarge", "ml.g5.8xlarge", "ml.g5.12xlarge", "ml.g5.16xlarge", "ml.g5.24xlarge", "ml.g5.48xlarge", "ml.g6.xlarge", "ml.g6.2xlarge", "ml.g6.4xlarge", "ml.g6.8xlarge", "ml.g6.12xlarge", "ml.g6.16xlarge"
      ]
      # By omitting hidden_app_types and hidden_ml_tools entirely, all app types and ML tools should be visible by default
    }
    security_groups = [
      aws_security_group.sagemaker_jupyterlab_sg.id
    ]

    space_storage_settings {
      default_ebs_storage_settings {
        default_ebs_volume_size_in_gb = 5
        maximum_ebs_volume_size_in_gb = 100
      }
    }
  }

  default_space_settings {
    execution_role = aws_iam_role.sagemaker_jupyterlab_execution_role.arn

    security_groups = [
      aws_security_group.sagemaker_jupyterlab_sg.id
    ]

    # Add custom file system for spaces
    custom_file_system_config {
      efs_file_system_config {
        file_system_id   = aws_efs_file_system.shared_efs.id
        file_system_path = "/"
      }
    }

    space_storage_settings {
      default_ebs_storage_settings {
        default_ebs_volume_size_in_gb = 5
        maximum_ebs_volume_size_in_gb = 100
      }
    }
  }

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    var.security_group_tags,
    {
      "Name"          = "jupyterlab-sagemaker-${var.env}-domain",
      "map-migrated"  = "migDJ69VCCMLC",
      "CostCentre"    = "10350_datascience"
    }
  )
}

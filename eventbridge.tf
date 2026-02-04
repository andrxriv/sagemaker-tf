# ==============================================================================
# EventBridge Rule and Lambda Function for SageMaker CreateUserProfile Events
# ==============================================================================

# ---------------------------------------------------------------------------
# Lambda Function to handle CreateUserProfile events
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "create_user_profile_handler" {
  filename         = "create_user_profile_handler.zip"
  function_name    = "sagemaker-create-user-profile-handler-${var.env}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      efs_id    = aws_efs_file_system.shared_efs.id
      domain_id = aws_sagemaker_domain.jupyterlab_domain.id
    }
  }

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "sagemaker-create-user-profile-handler"
    }
  )
}

# ---------------------------------------------------------------------------
# Lambda function code
# ---------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "create_user_profile_handler.zip"
  
  source {
    content = <<EOF
import json
import boto3
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

sm_client = boto3.client('sagemaker')
efs_client = boto3.client('efs')

def lambda_handler(event, context):
    """
    Handle SageMaker CreateUserProfile events from EventBridge
    Creates private EFS access points and updates user profile configurations
    """
    logger.info(f"Received CreateUserProfile event: {json.dumps(event, indent=2)}")
    
    try:
        # Get EFS and Domain ID from environment
        file_system = os.environ['efs_id']
        domain_id = os.environ['domain_id']    
        
        logger.info(f"Processing domain: {domain_id}")
        logger.info(f"Using EFS: {file_system}")
        
        # Extract user profile name from the event
        detail = event.get('detail', {})
        response_elements = detail.get('responseElements', {})
        user_profile_name = response_elements.get('userProfileName', '')
        
        if not user_profile_name:
            logger.error("Could not extract user profile name from event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing user profile name in event'})
            }
            
        logger.info(f"Processing new user profile: {user_profile_name}")
        
        try:
            # Create EFS Access Point for user-specific directory
            user_directory_path = f"/users/{user_profile_name}"
            access_point_name = f"{user_profile_name}-private-access-point"
            
            logger.info(f"Creating EFS access point for directory: {user_directory_path}")
            
            access_point_response = efs_client.create_access_point(
                FileSystemId=file_system,
                PosixUser={
                    'Uid': 200001,  # SageMaker default UID
                    'Gid': 1001     # SageMaker default GID
                },
                RootDirectory={
                    'Path': user_directory_path,
                    'CreationInfo': {
                        'OwnerUid': 200001,
                        'OwnerGid': 1001,
                        'Permissions': '0755'  # User directory permissions
                    }
                },
                Tags=[
                    {
                        'Key': 'Name',
                        'Value': access_point_name
                    },
                    {
                        'Key': 'UserProfile',
                        'Value': user_profile_name
                    },
                    {
                        'Key': 'Purpose',
                        'Value': 'SageMaker-User-Private-Directory'
                    }
                ]
            )
            
            access_point_id = access_point_response['AccessPointId']
            logger.info(f"Created EFS Access Point: {access_point_id}")
            
            # Wait for access point to be available
            logger.info("Waiting for access point to become available...")
            waiter = efs_client.get_waiter('access_point_available')
            waiter.wait(
                AccessPointId=access_point_id,
                WaiterConfig={'Delay': 5, 'MaxAttempts': 20}
            )
            
            # Update SageMaker user profile with the new access point
            logger.info(f"Updating user profile: {user_profile_name}")
            
            # Get current user profile to preserve existing settings
            current_profile = sm_client.describe_user_profile(
                DomainId=domain_id,
                UserProfileName=user_profile_name
            )
            
            current_settings = current_profile.get('UserSettings', {})
            current_custom_fs = current_settings.get('CustomFileSystemConfigs', [])
            
            # Add the new EFS configuration
            new_efs_config = {
                'EFSFileSystemConfig': {
                    'FileSystemId': file_system,
                    'FileSystemPath': user_directory_path
                }
            }
            
            # Check if this configuration already exists
            config_exists = any(
                config.get('EFSFileSystemConfig', {}).get('FileSystemPath') == user_directory_path
                for config in current_custom_fs
            )
            
            if not config_exists:
                current_custom_fs.append(new_efs_config)
                current_settings['CustomFileSystemConfigs'] = current_custom_fs
                
                # Update the user profile
                sm_client.update_user_profile(
                    DomainId=domain_id,
                    UserProfileName=user_profile_name,
                    UserSettings=current_settings
                )
                
                logger.info(f"Successfully updated user profile with EFS configuration")
            else:
                logger.info(f"EFS configuration already exists for user: {user_profile_name}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Successfully created private EFS directory for {user_profile_name}',
                    'userProfile': user_profile_name,
                    'domainId': domain_id,
                    'efsDirectory': user_directory_path,
                    'accessPointId': access_point_id,
                    'fileSystemId': file_system
                })
            }
            
        except Exception as user_error:
            logger.error(f"Error processing user {user_profile_name}: {str(user_error)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f'Failed to process user profile: {str(user_error)}',
                    'userProfile': user_profile_name,
                    'domainId': domain_id
                })
            }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF
    filename = "index.py"
  }
}

# ---------------------------------------------------------------------------
# IAM Role for Lambda Execution
# ---------------------------------------------------------------------------
resource "aws_iam_role" "lambda_execution_role" {
  name = "sagemaker-create-user-profile-lambda-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.iam_role_tags,
    {
      Name = "lambda-sagemaker-event-handler"
    }
  )
}

# ---------------------------------------------------------------------------
# IAM Policy for Lambda Function
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "lambda_policy" {
  name = "sagemaker-create-user-profile-lambda-policy-${var.env}"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/sagemaker-create-user-profile-handler-${var.env}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:DescribeUserProfile",
          "sagemaker:UpdateUserProfile",
          "sagemaker:DescribeDomain",
          "sagemaker:ListUserProfiles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:TagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ---------------------------------------------------------------------------
# EventBridge Rule for CreateUserProfile events
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "create_user_profile_rule" {
  name        = "sagemaker-create-user-profile-rule-${var.env}"
  description = "Capture SageMaker CreateUserProfile events"
  
  event_pattern = jsonencode({
    source      = ["aws.sagemaker"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["sagemaker.amazonaws.com"]
      eventName   = ["CreateUserProfile"]
    }
  })

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "sagemaker-create-user-profile-rule"
    }
  )
}

# ---------------------------------------------------------------------------
# EventBridge Target - Lambda Function
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.create_user_profile_rule.name
  target_id = "CreateUserProfileLambdaTarget"
  arn       = aws_lambda_function.create_user_profile_handler.arn
}

# ---------------------------------------------------------------------------
# Lambda Permission for EventBridge
# ---------------------------------------------------------------------------
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_user_profile_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.create_user_profile_rule.arn
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group for Lambda
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/sagemaker-create-user-profile-handler-${var.env}"
  retention_in_days = 7

  tags = merge(
    var.overall_tags,
    var.environment_tags,
    {
      Name = "lambda-create-user-profile-logs"
    }
  )
}

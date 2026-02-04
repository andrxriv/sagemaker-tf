# ==============================================================================
# EventBridge Rule and Lambda Function for SageMaker CreateUserProfile Events
# ==============================================================================

# ---------------------------------------------------------------------------
# Lambda function code
# ---------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "create_user_profile_handler.zip"
  
  source {
    content = <<EOF
import json
import subprocess
import boto3
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

sm_client = boto3.client('sagemaker')

def lambda_handler(event, context):
    """
    Handle SageMaker CreateUserProfile events from EventBridge  
    Creates EFS directory for the specific user that was just created
    """
    logger.info(f"Lambda triggered by CreateUserProfile event")
    logger.info(f"Event received: {json.dumps(event, indent=2)}")
    
    try:
        # Get EFS and Domain ID from environment
        file_system = os.environ['efs_id']
        domain_id = os.environ['domain_id']    
        
        logger.info(f"Processing domain: {domain_id}")
        logger.info(f"Using EFS: {file_system}")
        
        # Extract user profile name from the event
        detail = event.get('detail', {})
        request_parameters = detail.get('requestParameters', {})
        user_profile_name = request_parameters.get('userProfileName', '')
        
        if not user_profile_name:
            logger.error("Could not extract user profile name from event requestParameters")
            logger.error(f"Event detail: {json.dumps(detail, indent=2)}")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing user profile name in event requestParameters'})
            }
            
        logger.info(f"Processing newly created user profile: {user_profile_name}")
        
        try:
            # Create user directory with permissions
            repository = f'/mnt/efs/{user_profile_name}'
            logger.info(f"Creating directory: {repository}")
            
            # Create directory (with -p flag for mkdir)
            mkdir_result = subprocess.call(['mkdir', '-p', repository])
            logger.info(f"mkdir result for {user_profile_name}: {mkdir_result}")
            
            # Set ownership to SageMaker default UID/GID
            chown_result = subprocess.call(['chown', '200001:1001', repository])
            logger.info(f"chown result for {user_profile_name}: {chown_result}")
            
            # Update SageMaker user profile
            response = sm_client.update_user_profile(
                DomainId=domain_id,
                UserProfileName=user_profile_name,
                UserSettings={
                    'CustomFileSystemConfigs': [
                        {
                            'EFSFileSystemConfig': {
                                'FileSystemId': file_system,
                                'FileSystemPath': f'/{user_profile_name}'
                            }
                        }
                    ]
                }
            )
            
            logger.info(f"Successfully processed user profile: {user_profile_name}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Successfully created EFS directory for {user_profile_name}',
                    'domain_id': domain_id,
                    'file_system': file_system,
                    'user_profile': user_profile_name,
                    'efs_directory': f'/{user_profile_name}'
                })
            }
            
        except Exception as user_error:
            logger.error(f"Error processing user {user_profile_name}: {str(user_error)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f'Failed to process user profile: {str(user_error)}',
                    'user_profile': user_profile_name,
                    'domain_id': domain_id
                })
            }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'domain_id': os.environ.get('domain_id', 'unknown'),
                'file_system': os.environ.get('efs_id', 'unknown')
            })
        }
EOF
    filename = "index.py"
  }
}

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

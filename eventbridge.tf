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
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.env
      REGION      = var.region
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
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Handle SageMaker CreateUserProfile events from EventBridge
    """
    logger.info(f"Received CreateUserProfile event: {json.dumps(event, indent=2)}")
    
    try:
        # Extract event details
        detail = event.get('detail', {})
        source = event.get('source', '')
        
        if source == 'aws.sagemaker':
            event_name = detail.get('eventName', '')
            
            if event_name == 'CreateUserProfile':
                # Extract user profile information
                user_profile_name = detail.get('responseElements', {}).get('userProfileName', '')
                domain_id = detail.get('responseElements', {}).get('domainId', '')
                
                logger.info(f"CreateUserProfile detected:")
                logger.info(f"  User Profile: {user_profile_name}")
                logger.info(f"  Domain ID: {domain_id}")
                logger.info(f"  Environment: {os.environ.get('ENVIRONMENT', 'unknown')}")
                
                # Add your custom logic here
                # Examples:
                # - Send notification to Slack/Teams
                # - Update database records
                # - Initialize user resources
                # - Set up user-specific configurations
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': f'Successfully processed CreateUserProfile for {user_profile_name}',
                        'userProfile': user_profile_name,
                        'domainId': domain_id
                    })
                }
            
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Event processed but no action taken'})
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
          "sagemaker:DescribeDomain"
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

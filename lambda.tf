# Lambda Function URL for Bedrock agent access (IAM authenticated)
# Includes rate limiting and input protection

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "enable_lambda_url" {
  description = "Enable Lambda Function URL for agent access (IAM authenticated)"
  type        = bool
  default     = true
}

variable "lambda_max_concurrency" {
  description = "Max concurrent Lambda executions (rate limiting)"
  type        = number
  default     = 5
}

variable "lambda_max_input_chars" {
  description = "Max input characters to protect against token abuse"
  type        = number
  default     = 20000
}

# -----------------------------------------------------------------------------
# Lambda IAM Role
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/bedrock-agent-${var.agent_name}:*"]
  }

  # Bedrock Agent Invocation
  statement {
    sid    = "BedrockAgentInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeAgent"
    ]
    resources = [
      "arn:aws:bedrock:${local.region}:${local.account_id}:agent-alias/*/TSTALIASID"
    ]
  }
}

resource "aws_iam_role" "lambda" {
  count = var.enable_lambda_url ? 1 : 0

  name               = "bedrock-agent-lambda-${var.agent_name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  count = var.enable_lambda_url ? 1 : 0

  name   = "bedrock-agent-invoke"
  role   = aws_iam_role.lambda[0].id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------
data "archive_file" "lambda" {
  count = var.enable_lambda_url ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform/lambda.zip"
}

resource "aws_lambda_function" "agent_proxy" {
  count = var.enable_lambda_url ? 1 : 0

  function_name = "bedrock-agent-${var.agent_name}"
  description   = "Proxy for Bedrock agent invocation"

  filename         = data.archive_file.lambda[0].output_path
  source_code_hash = data.archive_file.lambda[0].output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  # Rate limiting via reserved concurrency
  reserved_concurrent_executions = var.lambda_max_concurrency

  role = aws_iam_role.lambda[0].arn

  environment {
    variables = {
      AGENT_ID         = module.bedrock_agent.bedrock_agent[0].agent_id
      AGENT_ALIAS_ID   = "TSTALIASID"
      MAX_INPUT_CHARS  = tostring(var.lambda_max_input_chars)
    }
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group (bounded retention)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  count = var.enable_lambda_url ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.agent_proxy[0].function_name}"
  retention_in_days = 7

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Lambda Function URL (IAM Authenticated)
# -----------------------------------------------------------------------------
resource "aws_lambda_function_url" "agent" {
  count = var.enable_lambda_url ? 1 : 0

  function_name      = aws_lambda_function.agent_proxy[0].function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["Content-Type"]
    max_age       = 86400
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "lambda_function_url" {
  description = "URL to invoke the Bedrock agent (requires IAM authentication)"
  value       = var.enable_lambda_url ? aws_lambda_function_url.agent[0].function_url : null
}

output "awscurl_example" {
  description = "Example awscurl command to invoke the agent (pip install awscurl)"
  value = var.enable_lambda_url ? join("", [
    "awscurl --service lambda ",
    aws_lambda_function_url.agent[0].function_url,
    " -X POST -H 'Content-Type: application/json'",
    " -d '{\"text\": \"Summarize: Your text here...\"}'"
  ]) : null
}

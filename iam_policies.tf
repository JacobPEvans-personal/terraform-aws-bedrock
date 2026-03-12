# IAM Policies for Terraform Runner and Agent Execution Role
# Set create_iam_policies = true to apply these (not recommended - bootstrap manually)

variable "create_iam_policies" {
  description = "Whether to create IAM policies via Terraform (false = documentation only)"
  type        = bool
  default     = false
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Terraform Runner Policy (for the IAM user running terraform)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "terraform_runner" {
  # Bedrock full access (required for AWSCC provider)
  statement {
    sid       = "BedrockFullAccess"
    effect    = "Allow"
    actions   = ["bedrock:*"]
    resources = ["*"]
  }

  # CloudFormation (required for AWSCC provider)
  statement {
    sid       = "CloudFormationForAWSCC"
    effect    = "Allow"
    actions   = ["cloudformation:*"]
    resources = ["*"]
  }

  # IAM role management for BedrockAgents* roles
  statement {
    sid    = "IAMRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole"
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/BedrockAgents*"]
  }

  # STS caller identity
  statement {
    sid       = "STSCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # S3 state bucket access
  statement {
    sid    = "BedrockStateS3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::terraform-bedrock-state-${replace(local.region, "-", "")}-${local.account_id}",
      "arn:aws:s3:::terraform-bedrock-state-${replace(local.region, "-", "")}-${local.account_id}/*"
    ]
  }

  # DynamoDB state locking
  statement {
    sid    = "BedrockStateDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]
    resources = ["arn:aws:dynamodb:${local.region}:${local.account_id}:table/terraform-bedrock-locks-*"]
  }

  # S3 bucket creation
  statement {
    sid    = "S3BucketCreation"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:PutBucketVersioning",
      "s3:PutBucketEncryption",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketVersioning",
      "s3:GetBucketEncryption",
      "s3:GetBucketPublicAccessBlock"
    ]
    resources = ["arn:aws:s3:::terraform-bedrock-state-*"]
  }

  # DynamoDB table creation
  statement {
    sid    = "DynamoDBTableCreation"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable",
      "dynamodb:DeleteTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource"
    ]
    resources = ["arn:aws:dynamodb:${local.region}:${local.account_id}:table/terraform-bedrock-locks-*"]
  }

  # CloudWatch logging
  statement {
    sid    = "CloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:ListTagsLogGroup"
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock/*"]
  }

  # Lambda management for agent proxy
  statement {
    sid    = "LambdaManagement"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:ListVersionsByFunction",
      "lambda:PublishVersion",
      "lambda:CreateFunctionUrlConfig",
      "lambda:DeleteFunctionUrlConfig",
      "lambda:GetFunctionUrlConfig",
      "lambda:UpdateFunctionUrlConfig",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags"
    ]
    resources = [
      "arn:aws:lambda:${local.region}:${local.account_id}:function:bedrock-agent-*"
    ]
  }

  # IAM for Lambda execution role
  statement {
    sid    = "IAMLambdaRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/bedrock-agent-lambda-*"
    ]
  }

  # AWS Budgets Creation (requires wildcard resource)
  statement {
    sid       = "BudgetsCreation"
    effect    = "Allow"
    actions   = ["budgets:CreateBudget"]
    resources = ["*"]
  }

  # AWS Budgets Management (scoped to specific budget)
  statement {
    sid    = "BudgetsManagement"
    effect = "Allow"
    actions = [
      "budgets:DeleteBudget",
      "budgets:DescribeBudget",
      "budgets:ModifyBudget",
      "budgets:ViewBudget"
    ]
    resources = ["arn:aws:budgets::${local.account_id}:budget/bedrock-agent-*"]
  }
}

# -----------------------------------------------------------------------------
# Agent Inference Profile Policy (fixes module's incorrect ARN generation)
# Cross-region inference requires access to foundation model in all regions
# -----------------------------------------------------------------------------
locals {
  # Regions where Amazon Nova Micro is available for cross-region inference
  nova_regions = ["us-east-1", "us-east-2", "us-west-2"]
}

data "aws_iam_policy_document" "agent_inference_profile" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:UseInferenceProfile",
      "bedrock:GetInferenceProfile"
    ]
    resources = concat(
      ["arn:aws:bedrock:${local.region}:${local.account_id}:inference-profile/${var.foundation_model}"],
      [for r in local.nova_regions : "arn:aws:bedrock:${r}::foundation-model/amazon.nova-micro-v1:0"]
    )
  }
}

# -----------------------------------------------------------------------------
# Outputs (always available for reference, even when not creating resources)
# -----------------------------------------------------------------------------
output "terraform_runner_policy_json" {
  description = "IAM policy JSON for the Terraform runner user"
  value       = data.aws_iam_policy_document.terraform_runner.json
}

output "agent_inference_profile_policy_json" {
  description = "IAM policy JSON to fix agent inference profile permissions"
  value       = data.aws_iam_policy_document.agent_inference_profile.json
}

# -----------------------------------------------------------------------------
# Optional: Apply the agent inference profile fix to the agent role
# Only created when create_iam_policies = true
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "agent_inference_profile_fix" {
  count = var.create_iam_policies ? 1 : 0

  name   = "inference-profile-fix"
  role   = module.bedrock_agent.agent_resource_role_name
  policy = data.aws_iam_policy_document.agent_inference_profile.json
}

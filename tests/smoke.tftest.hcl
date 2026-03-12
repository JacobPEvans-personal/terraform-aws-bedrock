# Smoke tests for AWS provider v6 compatibility
# Uses mock_provider to run offline without real AWS credentials

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_region" {
    defaults = {
      id   = "us-east-2"
      name = "us-east-2"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }
}

mock_provider "archive" {}

mock_provider "awscc" {}

mock_provider "opensearch" {}

# ------------------------------------------------------------------
# Test 1: Config plans successfully with provider v6
# ------------------------------------------------------------------
run "provider_v6_compatibility" {
  command = plan

  variables {
    budget_alert_email = "test@example.com"
  }

  assert {
    condition     = output.terraform_runner_policy_json != ""
    error_message = "terraform_runner_policy_json output must be non-empty"
  }

  assert {
    condition     = output.agent_inference_profile_policy_json != ""
    error_message = "agent_inference_profile_policy_json output must be non-empty"
  }
}

# ------------------------------------------------------------------
# Test 2: Lambda function has correct runtime and handler
# ------------------------------------------------------------------
run "lambda_function_attributes" {
  command = plan

  variables {
    enable_lambda_url  = true
    budget_alert_email = "test@example.com"
  }

  assert {
    condition     = aws_lambda_function.agent_proxy[0].runtime == "python3.12"
    error_message = "Lambda runtime must be python3.12"
  }

  assert {
    condition     = aws_lambda_function.agent_proxy[0].handler == "index.lambda_handler"
    error_message = "Lambda handler must be index.lambda_handler"
  }

  assert {
    condition     = aws_lambda_function.agent_proxy[0].reserved_concurrent_executions == 5
    error_message = "Lambda reserved concurrency must equal default lambda_max_concurrency (5)"
  }
}

# ------------------------------------------------------------------
# Test 3: Lambda URL uses AWS_IAM auth type
# ------------------------------------------------------------------
run "lambda_url_iam_auth" {
  command = plan

  variables {
    enable_lambda_url  = true
    budget_alert_email = "test@example.com"
  }

  assert {
    condition     = aws_lambda_function_url.agent[0].authorization_type == "AWS_IAM"
    error_message = "Lambda URL must use AWS_IAM authorization"
  }
}

# ------------------------------------------------------------------
# Test 4: Lambda IAM role has correct name pattern
# ------------------------------------------------------------------
run "lambda_iam_role_name" {
  command = plan

  variables {
    enable_lambda_url  = true
    budget_alert_email = "test@example.com"
  }

  assert {
    condition     = aws_iam_role.lambda[0].name == "bedrock-agent-lambda-text-summarizer"
    error_message = "Lambda IAM role name must follow bedrock-agent-lambda-{agent_name} pattern"
  }
}

# ------------------------------------------------------------------
# Test 5: Budget resource is created when email is provided
# ------------------------------------------------------------------
run "budget_created_with_email" {
  command = plan

  variables {
    enable_budget      = true
    budget_alert_email = "alerts@example.com"
  }

  assert {
    condition     = aws_budgets_budget.bedrock[0].budget_type == "COST"
    error_message = "Budget must have COST budget type"
  }

  assert {
    condition     = aws_budgets_budget.bedrock[0].time_unit == "MONTHLY"
    error_message = "Budget must be MONTHLY"
  }
}

# Variable defaults and constraints tests

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
# Test 1: Default variable values
# ------------------------------------------------------------------
run "default_variable_values" {
  command = plan

  # No variable overrides — test all defaults

  assert {
    condition     = var.agent_name == "text-summarizer"
    error_message = "Default agent_name must be text-summarizer"
  }

  assert {
    condition     = var.foundation_model == "us.amazon.nova-micro-v1:0"
    error_message = "Default foundation_model must be us.amazon.nova-micro-v1:0"
  }

  assert {
    condition     = var.idle_session_ttl == 600
    error_message = "Default idle_session_ttl must be 600"
  }

  assert {
    condition     = var.lambda_max_concurrency == 5
    error_message = "Default lambda_max_concurrency must be 5"
  }

  assert {
    condition     = var.lambda_max_input_chars == 20000
    error_message = "Default lambda_max_input_chars must be 20000"
  }
}

# ------------------------------------------------------------------
# Test 2: enable_lambda_url = false disables Lambda resources
# ------------------------------------------------------------------
run "disable_lambda_url_removes_resources" {
  command = plan

  variables {
    enable_lambda_url = false
  }

  assert {
    condition     = length(aws_lambda_function.agent_proxy) == 0
    error_message = "aws_lambda_function.agent_proxy must not be created when enable_lambda_url=false"
  }

  assert {
    condition     = length(aws_lambda_function_url.agent) == 0
    error_message = "aws_lambda_function_url.agent must not be created when enable_lambda_url=false"
  }

  assert {
    condition     = length(aws_iam_role.lambda) == 0
    error_message = "aws_iam_role.lambda must not be created when enable_lambda_url=false"
  }
}

# ------------------------------------------------------------------
# Test 3: Budget not created without email
# ------------------------------------------------------------------
run "budget_not_created_without_email" {
  command = plan

  variables {
    enable_budget      = true
    budget_alert_email = ""
  }

  assert {
    condition     = length(aws_budgets_budget.bedrock) == 0
    error_message = "aws_budgets_budget.bedrock must not be created without budget_alert_email"
  }
}

# ------------------------------------------------------------------
# Test 4: Custom agent_name propagates to resource names
# ------------------------------------------------------------------
run "custom_agent_name_propagates" {
  command = plan

  variables {
    agent_name         = "my-custom-agent"
    enable_lambda_url  = true
    budget_alert_email = "test@example.com"
  }

  assert {
    condition     = aws_lambda_function.agent_proxy[0].function_name == "bedrock-agent-my-custom-agent"
    error_message = "Lambda function name must include the custom agent_name"
  }

  assert {
    condition     = aws_iam_role.lambda[0].name == "bedrock-agent-lambda-my-custom-agent"
    error_message = "IAM role name must include the custom agent_name"
  }
}

# AWS Budget with alerts for cost monitoring
# Primary protection is Lambda reserved concurrency (hard limit on executions)

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "enable_budget" {
  description = "Enable AWS Budget alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 10.0
}

variable "budget_alert_email" {
  description = "Email address for budget alerts (required if enable_budget=true)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# AWS Budget
# -----------------------------------------------------------------------------
resource "aws_budgets_budget" "bedrock" {
  count = var.enable_budget && var.budget_alert_email != "" ? 1 : 0

  name         = "bedrock-agent-${var.agent_name}"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Filter to Bedrock and Lambda costs only
  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock", "AWS Lambda"]
  }

  # Alert at 50%, 80%, and 100% thresholds
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_alert_email]
    }
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "budget_name" {
  description = "Name of the AWS Budget"
  value = (
    var.enable_budget && var.budget_alert_email != ""
    ? aws_budgets_budget.bedrock[0].name
    : null
  )
}

output "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  value       = var.enable_budget ? var.monthly_budget_usd : null
}

output "cost_protection_summary" {
  description = "Summary of cost protection measures"
  value = join("\n", [
    "Cost Protection:",
    "- Lambda concurrency: ${var.lambda_max_concurrency} max simultaneous",
    "- Input limit: ${var.lambda_max_input_chars} chars (~${floor(var.lambda_max_input_chars / 4)} tokens)",
    "- Budget alerts: ${var.enable_budget ? "$${var.monthly_budget_usd}/month" : "disabled"}",
    "",
    "Emergency shutoff:",
    "  aws lambda put-function-concurrency \\",
    "    --function-name bedrock-agent-${var.agent_name} \\",
    "    --reserved-concurrent-executions 0"
  ])
}

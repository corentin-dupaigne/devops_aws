output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "log_group_names" {
  description = "Container log group names (used by the Docker awslogs driver)."
  value       = { for k, g in aws_cloudwatch_log_group.containers : k => g.name }
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications."
  value       = aws_sns_topic.alerts.arn
}

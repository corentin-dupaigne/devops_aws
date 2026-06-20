# ---------------------------------------------------------------------------
# observability module — CloudWatch log groups, SNS alerting and metric alarms.
# The dashboard lives in dashboard.tf.
# ---------------------------------------------------------------------------

data "aws_region" "current" {}

# --- Container log groups (the Docker awslogs driver ships logs here) ---
resource "aws_cloudwatch_log_group" "containers" {
  for_each = toset(["frontend", "backend"])

  name              = "/${var.project}/${each.key}"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project}-logs-${each.key}" }
}

# --- SNS topic for alarm notifications (P2) ---
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Metric alarms -> SNS ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-alb-5xx"
  alarm_description   = "High rate of target 5xx responses on the ALB"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  period              = 300
  evaluation_periods  = 1
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "${var.project}-alb-unhealthy-hosts"
  alarm_description   = "Frontend target group has unhealthy hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 2
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  alarm_actions      = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization is high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  period              = 300
  evaluation_periods  = 2
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

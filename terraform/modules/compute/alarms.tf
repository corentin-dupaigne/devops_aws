# ---------------------------------------------------------------------------
# EC2 auto-recovery alarms (resilience without an ASG).
# A failed system status check triggers the ec2:recover action: the instance is
# recovered on healthy hardware, keeping its ID, private IP and EBS volumes.
# ---------------------------------------------------------------------------

data "aws_region" "current" {}

resource "aws_cloudwatch_metric_alarm" "auto_recover" {
  for_each = {
    frontend = aws_instance.frontend.id
    backend  = aws_instance.backend.id
  }

  alarm_name          = "${var.project}-${each.key}-auto-recover"
  alarm_description   = "Recover the ${each.key} instance on a failed system status check"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 60
  evaluation_periods  = 2

  dimensions = {
    InstanceId = each.value
  }

  # Built-in EC2 recover action.
  alarm_actions = ["arn:aws:automate:${data.aws_region.current.name}:ec2:recover"]
}

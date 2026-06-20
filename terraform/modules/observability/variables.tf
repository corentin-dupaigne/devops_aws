variable "project" {
  description = "Naming prefix."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (CloudWatch dimension)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Frontend target group ARN suffix (CloudWatch dimension)."
  type        = string
}

variable "frontend_instance_id" {
  description = "Frontend EC2 instance ID."
  type        = string
}

variable "backend_instance_id" {
  description = "Backend EC2 instance ID."
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance identifier."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for the container log groups."
  type        = number
  default     = 14
}

variable "alert_email" {
  description = "Optional email for SNS alarm notifications. Empty = no subscription."
  type        = string
  default     = ""
}

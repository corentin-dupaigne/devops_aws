variable "project" {
  description = "Naming prefix / tag applied to all resources."
  type        = string
  default     = "pomodoro"
}

variable "region" {
  description = "AWS region (locked to us-east-1 by the Learner Lab)."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones (minimum 2 required by the brief)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "The brief requires deploying across at least 2 AZs."
  }
}

variable "admin_cidr" {
  description = "CIDR allowed for SSH (port 22) on the EC2 instances. Use YOUR IP as /32, e.g. 203.0.113.4/32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid CIDR, e.g. 203.0.113.4/32."
  }
}

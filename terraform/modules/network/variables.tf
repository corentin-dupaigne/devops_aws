variable "project" {
  description = "Naming prefix."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones."
  type        = number
}

variable "admin_cidr" {
  description = "CIDR allowed for SSH on the EC2 instances (admin IP as /32)."
  type        = string
}

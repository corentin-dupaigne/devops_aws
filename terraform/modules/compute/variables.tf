variable "project" {
  description = "Naming prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (for the ALB target group)."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (ALB + EC2)."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "frontend_security_group_id" {
  description = "Security group ID for the frontend EC2."
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for the backend EC2."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (kept small for the Learner Lab budget)."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH (Learner Lab provides 'vockey')."
  type        = string
  default     = "vockey"
}

variable "instance_profile_name" {
  description = "Existing IAM instance profile (Learner Lab forbids creating roles)."
  type        = string
  default     = "LabInstanceProfile"
}

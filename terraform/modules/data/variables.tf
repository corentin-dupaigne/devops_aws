variable "project" {
  description = "Naming prefix."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs hosting the RDS instance (>= 2 AZ)."
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID attached to the RDS instance (db tier)."
  type        = string
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "pomodoro"
}

variable "db_username" {
  description = "Master username for the database."
  type        = string
  default     = "pomodoro"
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class (kept small for the Learner Lab budget)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ. Kept false for the lab; flip to true for real resilience."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7
}

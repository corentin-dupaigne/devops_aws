# ---------------------------------------------------------------------------
# DB connection details published to SSM Parameter Store.
# Ansible reads these on the backend host (via the instance profile) and injects
# them as environment variables into the container. No secret in the repo/IaC.
# ---------------------------------------------------------------------------

locals {
  ssm_prefix = "/${var.project}/db"
}

resource "aws_ssm_parameter" "db_host" {
  name        = "${local.ssm_prefix}/host"
  description = "RDS endpoint hostname"
  type        = "String"
  value       = aws_db_instance.this.address
}

resource "aws_ssm_parameter" "db_port" {
  name        = "${local.ssm_prefix}/port"
  description = "RDS port"
  type        = "String"
  value       = tostring(aws_db_instance.this.port)
}

resource "aws_ssm_parameter" "db_name" {
  name        = "${local.ssm_prefix}/name"
  description = "Database name"
  type        = "String"
  value       = var.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name        = "${local.ssm_prefix}/user"
  description = "Database username"
  type        = "String"
  value       = var.db_username
}

# The only secret: stored as a SecureString.
resource "aws_ssm_parameter" "db_password" {
  name        = "${local.ssm_prefix}/password"
  description = "Database password (generated)"
  type        = "SecureString"
  value       = random_password.db.result
}

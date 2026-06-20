output "db_endpoint" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS port."
  value       = aws_db_instance.this.port
}

output "ssm_prefix" {
  description = "SSM Parameter Store prefix holding the DB connection details."
  value       = local.ssm_prefix
}

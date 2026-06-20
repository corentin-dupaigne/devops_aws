output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB + EC2)."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (RDS)."
  value       = module.network.private_subnet_ids
}

output "security_group_ids" {
  description = "Chained security group IDs (alb / front / back / db)."
  value       = module.network.security_group_ids
}

output "db_endpoint" {
  description = "RDS endpoint hostname."
  value       = module.data.db_endpoint
}

output "db_ssm_prefix" {
  description = "SSM Parameter Store prefix holding the DB connection details."
  value       = module.data.ssm_prefix
}

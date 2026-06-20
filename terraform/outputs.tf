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

output "alb_dns_name" {
  description = "Public DNS name of the ALB (entry point of the app)."
  value       = module.compute.alb_dns_name
}

output "frontend_public_ip" {
  description = "Public IP of the frontend EC2 (Ansible inventory)."
  value       = module.compute.frontend_public_ip
}

output "backend_public_ip" {
  description = "Public IP of the backend EC2 (Ansible inventory)."
  value       = module.compute.backend_public_ip
}

output "backend_private_ip" {
  description = "Private IP of the backend EC2 (Nginx proxies /api to it)."
  value       = module.compute.backend_private_ip
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for the frontend and backend images."
  value       = module.compute.ecr_repository_urls
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

output "log_group_names" {
  description = "Container log group names."
  value       = module.observability.log_group_names
}

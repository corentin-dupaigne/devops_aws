output "alb_dns_name" {
  description = "Public DNS name of the ALB (entry point of the app)."
  value       = aws_lb.this.dns_name
}

output "frontend_public_ip" {
  description = "Public IP of the frontend EC2 (for the Ansible inventory)."
  value       = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  description = "Public IP of the backend EC2 (for the Ansible inventory)."
  value       = aws_instance.backend.public_ip
}

output "backend_private_ip" {
  description = "Private IP of the backend EC2 (Nginx proxies /api to it)."
  value       = aws_instance.backend.private_ip
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for the frontend and backend images."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix (for CloudWatch dimensions)."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Frontend target group ARN suffix (for CloudWatch dimensions)."
  value       = aws_lb_target_group.frontend.arn_suffix
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID."
  value       = aws_instance.frontend.id
}

output "backend_instance_id" {
  description = "Backend EC2 instance ID."
  value       = aws_instance.backend.id
}

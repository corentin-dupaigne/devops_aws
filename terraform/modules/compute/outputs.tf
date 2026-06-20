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

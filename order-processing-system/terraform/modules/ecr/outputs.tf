output "order_service_repository_url" {
  description = "Order service ECR repository URL"
  value       = aws_ecr_repository.order_service.repository_url
}

output "payment_worker_repository_url" {
  description = "Payment worker ECR repository URL"
  value       = aws_ecr_repository.payment_worker.repository_url
}

output "order_service_repository_name" {
  description = "Order service repository name"
  value       = aws_ecr_repository.order_service.name
}

output "payment_worker_repository_name" {
  description = "Payment worker repository name"
  value       = aws_ecr_repository.payment_worker.name
}
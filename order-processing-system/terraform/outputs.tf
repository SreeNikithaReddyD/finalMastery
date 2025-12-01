output "alb_dns" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.database.db_endpoint
}

output "rabbitmq_public_ip" {
  description = "RabbitMQ EC2 public IP"
  value       = module.messaging.rabbitmq_public_ip
}

output "rabbitmq_private_ip" {
  description = "RabbitMQ EC2 private IP"
  value       = module.messaging.rabbitmq_private_ip
}

output "ecr_order_service_url" {
  description = "ECR repository URL for order service"
  value       = module.ecr.order_service_repository_url
}

output "ecr_payment_worker_url" {
  description = "ECR repository URL for payment worker"
  value       = module.ecr.payment_worker_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "order_service_name" {
  description = "Order service name"
  value       = module.ecs.order_service_name
}

output "payment_worker_name" {
  description = "Payment worker service name"
  value       = module.ecs.payment_worker_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}
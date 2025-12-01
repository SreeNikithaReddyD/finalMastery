output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "order_service_name" {
  description = "Order service name"
  value       = aws_ecs_service.order_service.name
}

output "payment_worker_name" {
  description = "Payment worker service name"
  value       = aws_ecs_service.payment_worker.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}
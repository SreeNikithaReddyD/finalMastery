output "order_service_log_group" {
  description = "Order service log group name"
  value       = aws_cloudwatch_log_group.order_service.name
}

output "payment_worker_log_group" {
  description = "Payment worker log group name"
  value       = aws_cloudwatch_log_group.payment_worker.name
}
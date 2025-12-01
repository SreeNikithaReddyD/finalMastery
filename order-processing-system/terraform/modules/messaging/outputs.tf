output "rabbitmq_public_ip" {
  description = "RabbitMQ EC2 public IP"
  value       = aws_instance.rabbitmq.public_ip
}

output "rabbitmq_private_ip" {
  description = "RabbitMQ EC2 private IP"
  value       = aws_instance.rabbitmq.private_ip
}

output "rabbitmq_instance_id" {
  description = "RabbitMQ EC2 instance ID"
  value       = aws_instance.rabbitmq.id
}
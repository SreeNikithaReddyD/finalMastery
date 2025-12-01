output "db_endpoint" {
  description = "Database endpoint"
  value       = split(":", aws_db_instance.postgres.endpoint)[0]
}

output "db_address" {
  description = "Database address"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.postgres.port
}
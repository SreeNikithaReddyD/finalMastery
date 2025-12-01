variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "order-processing"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "postgres123"
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "orders"
}

variable "rabbitmq_user" {
  description = "RabbitMQ username"
  type        = string
  default     = "guest"
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  default     = "guest"
  sensitive   = true
}
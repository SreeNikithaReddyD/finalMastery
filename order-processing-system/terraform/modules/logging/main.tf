resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${var.project_name}-order-service"
  retention_in_days = var.retention_days

  tags = {
    Name = "${var.project_name}-order-service-logs"
  }
}

resource "aws_cloudwatch_log_group" "payment_worker" {
  name              = "/ecs/${var.project_name}-payment-worker"
  retention_in_days = var.retention_days

  tags = {
    Name = "${var.project_name}-payment-worker-logs"
  }
}
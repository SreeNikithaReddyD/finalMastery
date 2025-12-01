resource "aws_ecr_repository" "order_service" {
  name                 = "${var.project_name}-order-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-order-service"
  }
}

resource "aws_ecr_repository" "payment_worker" {
  name                 = "${var.project_name}-payment-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-payment-worker"
  }
}
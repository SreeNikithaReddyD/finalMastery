# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# IAM Role for ECS Task Execution
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "order_service" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 60
    interval            = 300
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_service.arn
  }
}

# Order Service Task Definition
resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.project_name}-order-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name  = "order-service"
    image = "${var.order_service_repository_url}:latest"
    
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "DB_NAME", value = var.db_name },
      { name = "RABBITMQ_URL", value = "amqp://${var.rabbitmq_user}:${var.rabbitmq_password}@${var.rabbitmq_host}:5672/" },
      { name = "QUEUE_NAME", value = "orders" },
      { name = "PORT", value = "8080" }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.order_service_log_group
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-order-service-task"
  }
}

# Payment Worker Task Definition
resource "aws_ecs_task_definition" "payment_worker" {
  family                   = "${var.project_name}-payment-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name  = "payment-worker"
    image = "${var.payment_worker_repository_url}:latest"
    
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = var.db_port },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "DB_NAME", value = var.db_name },
      { name = "RABBITMQ_URL", value = "amqp://${var.rabbitmq_user}:${var.rabbitmq_password}@${var.rabbitmq_host}:5672/" },
      { name = "QUEUE_NAME", value = "orders" }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.payment_worker_log_group
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-payment-worker-task"
  }
}

# Order Service ECS Service
resource "aws_ecs_service" "order_service" {
  name            = "${var.project_name}-order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order_service.arn
    container_name   = "order-service"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.main]

  tags = {
    Name = "${var.project_name}-order-service"
  }
}

# Payment Worker ECS Service
resource "aws_ecs_service" "payment_worker" {
  name            = "${var.project_name}-payment-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payment_worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = true
  }

  tags = {
    Name = "${var.project_name}-payment-worker"
  }
}
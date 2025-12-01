terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Network Module
module "network" {
  source = "./modules/network"
  
  project_name = var.project_name
  aws_region   = var.aws_region
}

# Logging Module
module "logging" {
  source = "./modules/logging"
  
  project_name = var.project_name
}

# Database Module
module "database" {
  source = "./modules/database"
  
  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  db_security_group_id = module.network.db_security_group_id
  db_username         = var.db_username
  db_password         = var.db_password
  db_name             = var.db_name
}

# Messaging Module (RabbitMQ on EC2)
module "messaging" {
  source = "./modules/messaging"
  
  project_name               = var.project_name
  vpc_id                     = module.network.vpc_id
  public_subnet_id           = module.network.public_subnet_ids[0]
  rabbitmq_security_group_id = module.network.rabbitmq_security_group_id
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  project_name = var.project_name
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  project_name               = var.project_name
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  private_subnet_ids         = module.network.private_subnet_ids
  ecs_security_group_id      = module.network.ecs_security_group_id
  alb_security_group_id      = module.network.alb_security_group_id
  
  order_service_repository_url = module.ecr.order_service_repository_url
  payment_worker_repository_url = module.ecr.payment_worker_repository_url
  
  order_service_log_group = module.logging.order_service_log_group
  payment_worker_log_group = module.logging.payment_worker_log_group
  
  db_host         = module.database.db_endpoint
  db_port         = "5432"
  db_username     = var.db_username
  db_password     = var.db_password
  db_name         = var.db_name
  
  rabbitmq_host     = module.messaging.rabbitmq_private_ip
  rabbitmq_user     = var.rabbitmq_user
  rabbitmq_password = var.rabbitmq_password
}
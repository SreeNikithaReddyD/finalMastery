#!/bin/bash

# Build Docker images and push to ECR
# Usage: ./scripts/build-and-push.sh

set -e

echo "========================================"
echo "Building and Pushing Docker Images"
echo "========================================"
echo ""

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "ECR Registry: $ECR_REGISTRY"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
echo "✅ Logged in to ECR"
echo ""

# Get repository names from Terraform output
cd terraform
ORDER_SERVICE_REPO=$(terraform output -raw ecr_order_service_url)
PAYMENT_WORKER_REPO=$(terraform output -raw ecr_payment_worker_url)
cd ..

echo "Order Service Repo: $ORDER_SERVICE_REPO"
echo "Payment Worker Repo: $PAYMENT_WORKER_REPO"
echo ""

echo "Building Order Service for linux/amd64..."
docker buildx build --platform linux/amd64 -f deployments/aws/Dockerfile.order-service -t order-service:latest ./src --load
docker tag order-service:latest $ORDER_SERVICE_REPO:latest
echo "✅ Order Service built"
echo ""

echo "Building Payment Worker for linux/amd64..."
docker buildx build --platform linux/amd64 -f deployments/aws/Dockerfile.payment-worker -t payment-worker:latest ./src --load
docker tag payment-worker:latest $PAYMENT_WORKER_REPO:latest
echo "✅ Payment Worker built"

echo "Pushing Order Service to ECR..."
docker push $ORDER_SERVICE_REPO:latest
echo "✅ Order Service pushed"
echo ""

echo "Pushing Payment Worker to ECR..."
docker push $PAYMENT_WORKER_REPO:latest
echo "✅ Payment Worker pushed"
echo ""

echo "========================================"
echo "✅ All images built and pushed!"
echo "========================================"
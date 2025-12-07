#!/bin/bash

# Deploy/Update ECS services
# Usage: ./scripts/AWS/deploy-ecs.sh

set -e

echo "========================================"
echo "Deploying to AWS ECS"
echo "========================================"
echo ""

cd terraform

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
ORDER_SERVICE=$(terraform output -raw order_service_name)
PAYMENT_WORKER=$(terraform output -raw payment_worker_name)
ALB_DNS=$(terraform output -raw alb_dns)

echo "ECS Cluster: $CLUSTER_NAME"
echo "Order Service: $ORDER_SERVICE"
echo "Payment Worker: $PAYMENT_WORKER"
echo ""

echo "Updating Order Service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $ORDER_SERVICE \
    --force-new-deployment \
    --no-cli-pager > /dev/null

echo "✅ Order Service deployment initiated"
echo ""

echo "Updating Payment Worker..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $PAYMENT_WORKER \
    --force-new-deployment \
    --no-cli-pager > /dev/null

echo "✅ Payment Worker deployment initiated"
echo ""

echo "Waiting for services to stabilize..."
echo "(This may take 2-3 minutes)"
echo ""

aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $ORDER_SERVICE $PAYMENT_WORKER

echo ""
echo "========================================"
echo "✅ Deployment Complete!"
echo "========================================"
echo ""

cd ..

echo "Application available at:"
echo "http://$ALB_DNS"
echo ""
echo "Test with:"
echo "  curl http://$ALB_DNS/health"
echo ""
echo "Run full test suite:"
echo "  ./scripts/AWS/test-suite.sh http://$ALB_DNS aws"
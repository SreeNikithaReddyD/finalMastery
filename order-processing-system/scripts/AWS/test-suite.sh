#!/bin/bash

# AWS Test Suite
# Usage: ./scripts/AWS/test-suite.sh <alb_url> aws

set -e

BASE_URL=${1}
ENV_NAME=${2:-"aws"}
RESULTS_DIR="../../testing/AWS"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/${ENV_NAME}_results_${TIMESTAMP}.txt"

mkdir -p $RESULTS_DIR

echo "========================================"
echo "AWS Test Suite"
echo "========================================"
echo "Environment: $ENV_NAME"
echo "Target: $BASE_URL"
echo "Results: $RESULTS_FILE"
echo "========================================"
echo ""

exec > >(tee -a "$RESULTS_FILE") 2>&1

echo "========================================="
echo "PHASE 1: FUNCTIONAL TESTS"
echo "========================================="
echo ""

echo "Test 1.1: Health Check"
echo "---"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" $BASE_URL/health)
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -n 1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HEALTH_CODE" == "200" ]; then
    echo "✓ PASS: Health check returned 200"
    echo "Response: $HEALTH_BODY"
else
    echo "✗ FAIL: Health check returned $HEALTH_CODE"
fi
echo ""

echo "Test 1.2: Order Creation"
echo "---"
ORDER_RESPONSE=$(curl -s -X POST $BASE_URL/orders \
    -H "Content-Type: application/json" \
    -d '{
        "customer_id": "aws-test-user",
        "items": ["laptop", "mouse", "keyboard"],
        "total": 1599.99
    }')

ORDER_ID=$(echo $ORDER_RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$ORDER_ID" ]; then
    echo "✓ PASS: Order created"
    echo "Order ID: $ORDER_ID"
else
    echo "✗ FAIL: Failed to create order"
fi
echo ""

echo "Test 1.3: Metrics"
echo "---"
curl -s $BASE_URL/metrics | python3 -m json.tool 2>/dev/null || curl -s $BASE_URL/metrics
echo ""

echo "========================================="
echo "PHASE 2: PERFORMANCE TESTS"
echo "========================================="
echo ""

echo "Test 2.1: Baseline Load Test (1000 req, 50 concurrent)"
echo "---"
./scripts/AWS/load-test.sh $BASE_URL 1000 50
echo ""

echo "Test 2.2: Low Concurrency (500 req, 10 concurrent)"
echo "---"
./scripts/AWS/load-test.sh $BASE_URL 500 10
echo ""

echo "Test 2.3: High Concurrency (2000 req, 100 concurrent)"
echo "---"
./scripts/AWS/load-test.sh $BASE_URL 2000 100
echo ""

echo "========================================="
echo "FINAL METRICS"
echo "========================================="
curl -s $BASE_URL/metrics | python3 -m json.tool 2>/dev/null || curl -s $BASE_URL/metrics
echo ""

echo "========================================="
echo "TEST SUITE COMPLETE"
echo "========================================="
echo "Results: $RESULTS_FILE"
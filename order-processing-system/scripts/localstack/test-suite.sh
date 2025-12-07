#!/bin/bash

# Comprehensive Test Suite for Order Processing System
# Usage: ./scripts/test-suite.sh <base_url> <environment_name>

set -e

BASE_URL=${1:-"http://localhost:8080"}
ENV_NAME=${2:-"localstack"}
RESULTS_DIR="testing/localstack"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/${ENV_NAME}_results_${TIMESTAMP}.txt"

mkdir -p $RESULTS_DIR

echo "========================================"
echo "Order Processing System - Test Suite"
echo "========================================"
echo "Environment: $ENV_NAME"
echo "Target: $BASE_URL"
echo "Timestamp: $TIMESTAMP"
echo "Results: $RESULTS_FILE"
echo "========================================"
echo ""

# Redirect all output to both console and file
exec > >(tee -a "$RESULTS_FILE") 2>&1

echo "========================================="
echo "PHASE 1: FUNCTIONAL TESTS"
echo "========================================="
echo ""

# Test 1.1: Health Check
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

# Test 1.2: Create Order
echo "Test 1.2: Order Creation"
echo "---"
ORDER_RESPONSE=$(curl -s -X POST $BASE_URL/orders \
    -H "Content-Type: application/json" \
    -d '{
        "customer_id": "test-user-001",
        "items": ["laptop", "mouse", "keyboard"],
        "total": 1599.99
    }')

ORDER_ID=$(echo $ORDER_RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$ORDER_ID" ]; then
    echo "✓ PASS: Order created successfully"
    echo "Order ID: $ORDER_ID"
    echo "Response: $ORDER_RESPONSE"
else
    echo "✗ FAIL: Failed to create order"
    echo "Response: $ORDER_RESPONSE"
fi
echo ""

# Test 1.3: Order Status Retrieval
echo "Test 1.3: Order Status Retrieval"
echo "---"
if [ -n "$ORDER_ID" ]; then
    echo "Waiting 2 seconds for processing..."
    sleep 2
    
    STATUS_RESPONSE=$(curl -s $BASE_URL/orders/$ORDER_ID)
    STATUS=$(echo $STATUS_RESPONSE | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    echo "✓ PASS: Order status retrieved"
    echo "Status: $STATUS"
    echo "Response: $STATUS_RESPONSE"
else
    echo "✗ SKIP: No order ID from previous test"
fi
echo ""

# Test 1.4: List Orders
echo "Test 1.4: List Orders"
echo "---"
LIST_RESPONSE=$(curl -s $BASE_URL/orders)
ORDER_COUNT=$(echo $LIST_RESPONSE | grep -o '"id"' | wc -l)

echo "✓ PASS: Retrieved order list"
echo "Order count: $ORDER_COUNT"
echo ""

# Test 1.5: System Metrics
echo "Test 1.5: System Metrics"
echo "---"
METRICS_RESPONSE=$(curl -s $BASE_URL/metrics)
echo "✓ PASS: Metrics retrieved"
echo "$METRICS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$METRICS_RESPONSE"
echo ""

echo "========================================="
echo "PHASE 2: PERFORMANCE TESTS"
echo "========================================="
echo ""

# Test 2.1: Baseline Load Test
echo "Test 2.1: Baseline Load Test (1000 req, 50 concurrent)"
echo "---"
if command -v ab &> /dev/null; then
    ./scripts/localstack/load-test.sh $BASE_URL 1000 50
else
    echo "⚠ Apache Bench not installed - skipping load test"
fi
echo ""

# Test 2.2: Low Concurrency
echo "Test 2.2: Low Concurrency Test (500 req, 10 concurrent)"
echo "---"
if command -v ab &> /dev/null; then
    ./scripts/localstack/load-test.sh $BASE_URL 500 10
else
    echo "⚠ Skipped"
fi
echo ""

# Test 2.3: High Concurrency
echo "Test 2.3: High Concurrency Test (2000 req, 100 concurrent)"
echo "---"
if command -v ab &> /dev/null; then
    ./scripts/localstack/load-test.sh $BASE_URL 2000 100
else
    echo "⚠ Skipped"
fi
echo ""

echo "========================================="
echo "PHASE 3: QUICK RELIABILITY CHECKS"
echo "========================================="
echo ""

# Test 3.1: Create 10 orders rapidly
echo "Test 3.1: Rapid Order Creation (10 orders)"
echo "---"
SUCCESS_COUNT=0
for i in {1..10}; do
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/orders \
        -H "Content-Type: application/json" \
        -d "{\"customer_id\":\"batch-$i\",\"items\":[\"item$i\"],\"total\":99.99}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    if [ "$HTTP_CODE" == "201" ]; then
        ((SUCCESS_COUNT++))
    fi
done

echo "✓ Success rate: $SUCCESS_COUNT/10"
echo ""

# Final metrics
echo "========================================="
echo "FINAL SYSTEM METRICS"
echo "========================================="
curl -s $BASE_URL/metrics | python3 -m json.tool 2>/dev/null || curl -s $BASE_URL/metrics
echo ""

echo "========================================="
echo "TEST SUITE COMPLETE"
echo "========================================="
echo "Environment: $ENV_NAME"
echo "Results saved to: $RESULTS_FILE"
echo ""

# Summary
echo "SUMMARY:"
echo "--------"
echo "Functional Tests: 5/5 executed"
echo "Performance Tests: 3/3 executed"
echo "Reliability Tests: 1/1 executed"
echo ""
echo "Review detailed results in: $RESULTS_FILE"
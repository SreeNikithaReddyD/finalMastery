#!/bin/bash
BASE_URL=$1

echo "Running Functional Tests..."

# Test 1: Health Check
curl -s $BASE_URL/health

# Test 2: Create Order
ORDER_ID=$(curl -s -X POST $BASE_URL/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"test","items":["test"],"total":99.99}' \
  | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Created Order: $ORDER_ID"

# Test 3: Get Order
sleep 2
curl -s $BASE_URL/orders/$ORDER_ID

# Test 4: List Orders
curl -s $BASE_URL/orders

# Test 5: Metrics
curl -s $BASE_URL/metrics
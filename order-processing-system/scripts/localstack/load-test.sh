#!/bin/bash

# Order Processing System - Load Test Script
# Usage: ./load-test.sh <base_url> <num_requests> <concurrency>

set -e

BASE_URL=${1:-"http://localhost:8080"}
NUM_REQUESTS=${2:-1000}
CONCURRENCY=${3:-50}

echo "========================================"
echo "Order Processing System - Load Test"
echo "========================================"
echo "Target: $BASE_URL"
echo "Total Requests: $NUM_REQUESTS"
echo "Concurrency: $CONCURRENCY"
echo "========================================"
echo ""

echo "Checking service health..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
if [ "$HEALTH_CHECK" != "200" ]; then
    echo "❌ Error: Service is not healthy (HTTP $HEALTH_CHECK)"
    exit 1
fi
echo "✅ Service is healthy"
echo ""

ORDER_DATA=$(cat <<EOF
{
  "customer_id": "load-test-customer",
  "items": ["laptop", "mouse", "keyboard"],
  "total": 1599.99
}
EOF
)

echo "$ORDER_DATA" > /tmp/order_data.json

echo "Starting load test..."
echo "========================================"
echo ""

START_TIME=$(date +%s)

if command -v ab &> /dev/null; then
    echo "Using Apache Bench (ab)..."
    echo ""
    ab -n $NUM_REQUESTS -c $CONCURRENCY -p /tmp/order_data.json -T application/json "$BASE_URL/orders"
else
    echo "⚠️  Apache Bench (ab) not found!"
    echo ""
    echo "Falling back to curl-based testing..."
    echo ""
    
    SUCCESS=0
    FAILED=0
    
    for i in $(seq 1 $NUM_REQUESTS); do
        HTTP_CODE=$(curl -X POST "$BASE_URL/orders" \
            -H "Content-Type: application/json" \
            -d "$ORDER_DATA" \
            -s -o /dev/null -w "%{http_code}")
        
        if [ "$HTTP_CODE" == "201" ]; then
            ((SUCCESS++))
        else
            ((FAILED++))
        fi
        
        if [ $((i % CONCURRENCY)) -eq 0 ]; then
            echo "Progress: $i/$NUM_REQUESTS requests sent"
        fi
    done
    
    echo ""
    echo "Curl-based test results:"
    echo "  Successful: $SUCCESS"
    echo "  Failed: $FAILED"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "========================================"
echo "✅ Load test completed in ${DURATION}s"
echo "========================================"
echo ""

echo "Current System Metrics:"
echo "========================================"
curl -s "$BASE_URL/metrics" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/metrics"
echo ""

rm -f /tmp/order_data.json

echo ""
echo "✅ Done!"
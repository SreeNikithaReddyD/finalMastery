#!/bin/bash

# Copy from localstack version - same script works for both
# Just copying to AWS folder for organization

BASE_URL=${1:-"http://localhost:8080"}
NUM_REQUESTS=${2:-1000}
CONCURRENCY=${3:-50}

echo "========================================"
echo "AWS Load Test"
echo "========================================"
echo "Target: $BASE_URL"
echo "Requests: $NUM_REQUESTS"
echo "Concurrency: $CONCURRENCY"
echo "========================================"
echo ""

ORDER_DATA='{"customer_id":"load-test","items":["laptop"],"total":999.99}'
echo "$ORDER_DATA" > /tmp/order_data.json

if command -v ab &> /dev/null; then
    ab -n $NUM_REQUESTS -c $CONCURRENCY -p /tmp/order_data.json -T application/json "$BASE_URL/orders"
else
    echo "Apache Bench not found!"
fi

echo ""
echo "Metrics:"
curl -s "$BASE_URL/metrics" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/metrics"

rm -f /tmp/order_data.json
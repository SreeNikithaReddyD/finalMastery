#!/bin/bash
BASE_URL=$1

echo "Running Performance Tests..."

./scripts/load-test.sh $BASE_URL 1000 50
./scripts/load-test.sh $BASE_URL 500 10
./scripts/load-test.sh $BASE_URL 2000 100
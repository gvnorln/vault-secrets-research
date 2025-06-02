#!/bin/bash

mkdir -p data/app-test-results

echo "=== Testing Applications ==="

# Test static secrets app
echo "Testing Static Secrets App..."
kubectl port-forward svc/static-secrets-service 8080:5000 &
STATIC_PID=$!
sleep 5

echo "Gathering Static App Results..."
STATIC_HEALTH=$(curl -s http://localhost:8080/health | jq .)
STATIC_USERS=$(curl -s http://localhost:8080/users | jq '.metrics')
STATIC_METRICS=$(curl -s http://localhost:8080/metrics | jq .)

kill $STATIC_PID

# Gabungkan semua hasil static dalam satu objek JSON
echo -e "{
  \"health\": $STATIC_HEALTH,
  \"users_metrics\": $STATIC_USERS,
  \"metrics\": $STATIC_METRICS
}" | jq . > data/app-test-results/static_results.json

cat data/app-test-results/static_results.json

# Test vault secrets app  
echo -e "\nTesting Vault Secrets App..."
kubectl port-forward svc/vault-secrets-service 8081:5000 &
VAULT_PID=$!
sleep 5

echo "Gathering Vault App Results..."
VAULT_HEALTH=$(curl -s http://localhost:8081/health | jq .)
VAULT_STATUS=$(curl -s http://localhost:8081/vault-status | jq .)
VAULT_USERS=$(curl -s http://localhost:8081/users | jq '.metrics')
VAULT_METRICS=$(curl -s http://localhost:8081/metrics | jq .)

kill $VAULT_PID

# Gabungkan semua hasil vault dalam satu objek JSON
echo -e "{
  \"health\": $VAULT_HEALTH,
  \"vault_status\": $VAULT_STATUS,
  \"users_metrics\": $VAULT_USERS,
  \"metrics\": $VAULT_METRICS
}" | jq . > data/app-test-results/vault_results.json

cat data/app-test-results/vault_results.json

echo -e "\n=== Test completed ==="

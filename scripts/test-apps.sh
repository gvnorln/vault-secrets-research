#!/bin/bash

echo "=== Testing Applications ==="

# Test static secrets app
echo "Testing Static Secrets App..."
kubectl port-forward svc/static-secrets-service 8080:5000 &
STATIC_PID=$!
sleep 5

echo "Health check - Static:"
curl -s http://localhost:8080/health | jq .

echo "Users endpoint - Static:"
curl -s http://localhost:8080/users | jq '.metrics'

echo "Metrics - Static:"
curl -s http://localhost:8080/metrics | jq .

kill $STATIC_PID

# Test vault secrets app  
echo -e "\nTesting Vault Secrets App..."
kubectl port-forward svc/vault-secrets-service 8081:5000 &
VAULT_PID=$!
sleep 5

echo "Health check - Vault:"
curl -s http://localhost:8081/health | jq .

echo "Vault status:"
curl -s http://localhost:8081/vault-status | jq .

echo "Users endpoint - Vault:"
curl -s http://localhost:8081/users | jq '.metrics'

echo "Metrics - Vault:"
curl -s http://localhost:8081/metrics | jq .

kill $VAULT_PID

echo -e "\n=== Test completed ==="

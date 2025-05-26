#!/bin/bash

echo "=== Local CI/CD Pipeline Test ==="

# Check prerequisites
echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "Docker required but not installed"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required but not installed"; exit 1; }
command -v minikube >/dev/null 2>&1 || { echo "minikube required but not installed"; exit 1; }

# Start minikube if not running
if ! minikube status | grep -q "Running"; then
    echo "Starting minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
fi

# Function to time execution
time_execution() {
    local start_time=$(date +%s.%N)
    "$@"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "Execution time: ${duration} seconds"
    return $?
}

# Deploy infrastructure
echo "=== Step 1: Deploy Infrastructure ==="
time_execution bash -c "
    kubectl apply -f k8s/postgres/ 2>/dev/null || true
    kubectl apply -f k8s/vault/ 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l app=postgres -n database --timeout=300s
    kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s
"

# Build applications
echo "=== Step 2: Build Applications ==="
time_execution bash -c "
    eval \$(minikube docker-env)
    cd test-apps/static-secrets-app && docker build -t static-secrets-app:v1.0 . && cd ../..
    cd test-apps/vault-secrets-app && docker build -t vault-secrets-app:v1.0 . && cd ../..
"

# Deploy applications
echo "=== Step 3: Deploy Applications ==="
time_execution bash -c "
    if [ -f vault-init-keys.txt ]; then
        ROOT_TOKEN=\$(grep 'Initial Root Token:' vault-init-keys.txt | awk '{print \$NF}')
        kubectl apply -f k8s/app/static-secrets-deployment.yaml
        sed \"s/REPLACE_WITH_ROOT_TOKEN/\$ROOT_TOKEN/g\" k8s/app/vault-secrets-deployment.yaml | kubectl apply -f -
        kubectl wait --for=condition=available deployment/static-secrets-app --timeout=300s
        kubectl wait --for=condition=available deployment/vault-secrets-app --timeout=300s
    else
        echo 'Warning: vault-init-keys.txt not found, skipping application deployment'
    fi
"

# Run performance tests
echo "=== Step 4: Performance Tests ==="
time_execution bash -c "
    kubectl port-forward svc/static-secrets-service 8080:5000 &
    STATIC_PID=\$!
    kubectl port-forward svc/vault-secrets-service 8081:5000 &
    VAULT_PID=\$!
    
    sleep 10
    
    echo 'Testing static app...'
    curl -s http://localhost:8080/health | jq .
    
    echo 'Testing vault app...'  
    curl -s http://localhost:8081/health | jq .
    
    kill \$STATIC_PID \$VAULT_PID
"

echo "=== Local CI/CD Test Complete ==="
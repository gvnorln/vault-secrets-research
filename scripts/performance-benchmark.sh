#!/bin/bash

ITERATIONS=${1:-50}
OUTPUT_DIR="performance-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Vault Performance Benchmark ==="
echo "Iterations: $ITERATIONS"
echo "Output Directory: $OUTPUT_DIR"

# Create output directory
mkdir -p $OUTPUT_DIR

# Install dependencies
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    sudo dnf install -y jq bc
fi

# Port forward applications
echo "Setting up port forwards..."
kubectl port-forward svc/static-secrets-service 8080:5000 &
STATIC_PID=$!
kubectl port-forward svc/vault-secrets-service 8081:5000 &
VAULT_PID=$!

sleep 10

# Create results file
RESULTS_FILE="$OUTPUT_DIR/benchmark_results_${TIMESTAMP}.json"
echo '{"benchmark_info":{"iterations":'$ITERATIONS',"timestamp":"'$TIMESTAMP'"},"results":[]}' > $RESULTS_FILE

echo "Running benchmark tests..."

for i in $(seq 1 $ITERATIONS); do
    echo -n "Progress: $i/$ITERATIONS"
    
    # Test static app
    STATIC_START=$(date +%s.%N)
    STATIC_RESPONSE=$(curl -s http://localhost:8080/users 2>/dev/null)
    STATIC_END=$(date +%s.%N)
    STATIC_TIME=$(echo "$STATIC_END - $STATIC_START" | bc -l)
    
    # Test vault app
    VAULT_START=$(date +%s.%N)
    VAULT_RESPONSE=$(curl -s http://localhost:8081/users 2>/dev/null)
    VAULT_END=$(date +%s.%N)
    VAULT_TIME=$(echo "$VAULT_END - $VAULT_START" | bc -l)
    
    # Parse application metrics
    if [[ $STATIC_RESPONSE == *"metrics"* ]]; then
        STATIC_METRICS=$(echo "$STATIC_RESPONSE" | jq -c '.metrics // {}')
    else
        STATIC_METRICS='{}'
    fi
    
    if [[ $VAULT_RESPONSE == *"metrics"* ]]; then
        VAULT_METRICS=$(echo "$VAULT_RESPONSE" | jq -c '.metrics // {}')
        SECURITY_INFO=$(echo "$VAULT_RESPONSE" | jq -c '.security_info // {}')
    else
        VAULT_METRICS='{}'
        SECURITY_INFO='{}'
    fi
    
    # Calculate overhead
    OVERHEAD=$(echo "$VAULT_TIME - $STATIC_TIME" | bc -l)
    OVERHEAD_PERCENT=$(echo "scale=2; ($OVERHEAD / $STATIC_TIME) * 100" | bc -l)
    
    # Create result entry
    RESULT_ENTRY=$(cat << EOF
{
    "iteration": $i,
    "static_app": {
        "total_response_time": $STATIC_TIME,
        "metrics": $STATIC_METRICS
    },
    "vault_app": {
        "total_response_time": $VAULT_TIME, 
        "metrics": $VAULT_METRICS,
        "security_info": $SECURITY_INFO
    },
    "comparison": {
        "overhead_seconds": $OVERHEAD,
        "overhead_percentage": $OVERHEAD_PERCENT
    }
}

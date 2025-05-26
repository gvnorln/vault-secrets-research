#!/bin/bash

ITERATIONS=${1:-100}
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
EOF
    )
    
    # Add to results file
    jq ".results += [$RESULT_ENTRY]" $RESULTS_FILE > tmp.json && mv tmp.json $RESULTS_FILE
    
    echo " - Static: ${STATIC_TIME}s, Vault: ${VAULT_TIME}s, Overhead: ${OVERHEAD_PERCENT}%"
    
    # Brief pause between requests
    sleep 0.1
done

# Cleanup port forwards
kill $STATIC_PID $VAULT_PID 2>/dev/null

# Generate summary statistics
echo "=== Generating Summary Statistics ==="

SUMMARY_FILE="$OUTPUT_DIR/benchmark_summary_${TIMESTAMP}.json"

# Calculate statistics using jq
STATIC_STATS=$(jq -r '.results | map(.static_app.total_response_time) | {
    avg: (add / length),
    min: min,
    max: max,
    count: length
}' $RESULTS_FILE)

VAULT_STATS=$(jq -r '.results | map(.vault_app.total_response_time) | {
    avg: (add / length),
    min: min, 
    max: max,
    count: length
}' $RESULTS_FILE)

OVERHEAD_STATS=$(jq -r '.results | map(.comparison.overhead_seconds) | {
    avg: (add / length),
    min: min,
    max: max
}' $RESULTS_FILE)

OVERHEAD_PERCENT_STATS=$(jq -r '.results | map(.comparison.overhead_percentage) | {
    avg: (add / length),
    min: min,
    max: max
}' $RESULTS_FILE)

# Create summary
cat > $SUMMARY_FILE << EOF
{
    "benchmark_info": {
        "iterations": $ITERATIONS,
        "timestamp": "$TIMESTAMP",
        "test_date": "$(date -Iseconds)"
    },
    "statistics": {
            "static_app": $STATIC_STATS,
        "vault_app": $VAULT_STATS,
        "overhead": {
            "absolute_seconds": $OVERHEAD_STATS,
            "percentage": $OVERHEAD_PERCENT_STATS
        }
    },
    "recommendations": {
        "acceptable_overhead_threshold": "< 50%",
        "performance_grade": "$(
            AVG_OVERHEAD=$(echo $OVERHEAD_PERCENT_STATS | jq -r '.avg')
            if (( $(echo "$AVG_OVERHEAD < 25" | bc -l) )); then
                echo "A - Excellent"
            elif (( $(echo "$AVG_OVERHEAD < 50" | bc -l) )); then
                echo "B - Good"
            elif (( $(echo "$AVG_OVERHEAD < 100" | bc -l) )); then
                echo "C - Acceptable"
            else
                echo "D - Needs Optimization"
            fi
        )"
    }
}
EOF

# Generate detailed report
echo "=== Performance Report ==="
echo "Results saved to: $RESULTS_FILE"
echo "Summary saved to: $SUMMARY_FILE"

# Display key metrics
echo ""
echo "Key Performance Metrics:"
echo "========================"
jq -r '"Static App - Avg: " + (.statistics.static_app.avg | tostring) + "s, Min: " + (.statistics.static_app.min | tostring) + "s, Max: " + (.statistics.static_app.max | tostring) + "s"' $SUMMARY_FILE
jq -r '"Vault App  - Avg: " + (.statistics.vault_app.avg | tostring) + "s, Min: " + (.statistics.vault_app.min | tostring) + "s, Max: " + (.statistics.vault_app.max | tostring) + "s"' $SUMMARY_FILE
jq -r '"Overhead   - Avg: " + (.statistics.overhead.percentage.avg | tostring) + "%, Min: " + (.statistics.overhead.percentage.min | tostring) + "%, Max: " + (.statistics.overhead.percentage.max | tostring) + "%"' $SUMMARY_FILE
jq -r '"Grade: " + .recommendations.performance_grade' $SUMMARY_FILE

# Generate CSV for easy analysis
CSV_FILE="$OUTPUT_DIR/benchmark_data_${TIMESTAMP}.csv"
echo "iteration,static_time,vault_time,overhead_seconds,overhead_percentage" > $CSV_FILE
jq -r '.results[] | [.iteration, .static_app.total_response_time, .vault_app.total_response_time, .comparison.overhead_seconds, .comparison.overhead_percentage] | @csv' $RESULTS_FILE >> $CSV_FILE

echo ""
echo "CSV data saved to: $CSV_FILE"
echo "Benchmark complete!"
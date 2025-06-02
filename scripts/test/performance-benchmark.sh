#!/bin/bash

ITERATIONS=${1:-100}
OUTPUT_DIR="performance-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Vault Performance Benchmark ==="
echo "Iterations: $ITERATIONS"
echo "Output Directory: $OUTPUT_DIR"

mkdir -p $OUTPUT_DIR

if ! command -v jq &> /dev/null; then
    echo "Installing jq and bc..."
    sudo dnf install -y jq bc
fi

echo "Setting up port forwards..."
kubectl port-forward svc/static-secrets-service 8080:5000 &
STATIC_PID=$!
kubectl port-forward svc/vault-secrets-service 8081:5000 &
VAULT_PID=$!

trap 'kill $STATIC_PID $VAULT_PID 2>/dev/null' EXIT

sleep 10

RESULTS_FILE="$OUTPUT_DIR/benchmark_results_${TIMESTAMP}.json"
echo '{"benchmark_info":{"iterations":'$ITERATIONS',"timestamp":"'$TIMESTAMP'"},"results":[]}' > $RESULTS_FILE

LAST_CREDENTIAL=""
echo "Running benchmark tests..."

log_credential_rotation() {
    local start_time end_time duration

    echo "Rotating credentials for vault-app..." >&2

    start_time=$(date +%s.%N)
    kubectl exec -n default deploy/vault -- vault write -f database/rotate-role/my-role >/dev/null 2>&1

    for attempt in {1..20}; do
        RESPONSE=$(curl -s http://localhost:8081/users)
        CURRENT_USER=$(echo "$RESPONSE" | jq -r '.security_info.credentials_user // empty')

        if [[ "$CURRENT_USER" != "" && "$CURRENT_USER" != "$LAST_CREDENTIAL" ]]; then
            break
        fi
        sleep 0.5
    done

    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    echo "$duration"
}

for i in $(seq 1 $ITERATIONS); do
    echo -n "Progress: $i/$ITERATIONS"

    STATIC_START=$(date +%s.%N)
    STATIC_RESPONSE=$(curl -s http://localhost:8080/users)
    STATIC_END=$(date +%s.%N)
    STATIC_TIME=$(echo "$STATIC_END - $STATIC_START" | bc -l)

    VAULT_START=$(date +%s.%N)
    VAULT_RESPONSE=$(curl -s http://localhost:8081/users)
    VAULT_END=$(date +%s.%N)
    VAULT_TIME=$(echo "$VAULT_END - $VAULT_START" | bc -l)

    STATIC_METRICS=$(echo "$STATIC_RESPONSE" | jq -c '.metrics // {}')
    VAULT_METRICS=$(echo "$VAULT_RESPONSE" | jq -c '.metrics // {}')
    SECURITY_INFO=$(echo "$VAULT_RESPONSE" | jq -c '.security_info // {}')
    CURRENT_CREDENTIAL=$(echo "$SECURITY_INFO" | jq -r '.credentials_user // empty')

    OVERHEAD=$(echo "$VAULT_TIME - $STATIC_TIME" | bc -l)
    OVERHEAD_PERCENT=$(echo "scale=2; ($OVERHEAD / $STATIC_TIME) * 100" | bc -l)

    # ROTATION HANDLING
    ROTATION_PERFORMED=false
    ROTATION_TIME="null"

    if (( i % 10 == 0 )); then
        ROTATION_TIME=$(log_credential_rotation)
        echo "Credential rotated. Duration: ${ROTATION_TIME}s"
        ROTATION_PERFORMED=true
        LAST_CREDENTIAL="$CURRENT_CREDENTIAL"
    fi

    # Create JSON with proper null handling
    if [[ "$ROTATION_TIME" == "null" ]]; then
        ROTATION_TIME_JSON="null"
    else
        ROTATION_TIME_JSON="$ROTATION_TIME"
    fi

    RESULT_ENTRY=$(jq -n \
        --argjson iteration "$i" \
        --argjson static_time "$STATIC_TIME" \
        --argjson static_metrics "$STATIC_METRICS" \
        --argjson vault_time "$VAULT_TIME" \
        --argjson vault_metrics "$VAULT_METRICS" \
        --argjson security_info "$SECURITY_INFO" \
        --argjson overhead "$OVERHEAD" \
        --argjson overhead_percent "$OVERHEAD_PERCENT" \
        --argjson rotation_performed "$ROTATION_PERFORMED" \
        --argjson rotation_time "$ROTATION_TIME_JSON" \
        '{
            iteration: $iteration,
            static_app: {
                total_response_time: $static_time,
                metrics: $static_metrics
            },
            vault_app: {
                total_response_time: $vault_time,
                metrics: $vault_metrics,
                security_info: $security_info
            },
            comparison: {
                overhead_seconds: $overhead,
                overhead_percentage: $overhead_percent
            },
            rotation: {
                performed: $rotation_performed,
                duration_seconds: $rotation_time
            }
        }')

    jq ".results += [$RESULT_ENTRY]" $RESULTS_FILE > tmp.json && mv tmp.json $RESULTS_FILE
    echo " - Static: ${STATIC_TIME}s, Vault: ${VAULT_TIME}s, Overhead: ${OVERHEAD_PERCENT}%"

    sleep 0.1
done

echo "=== Generating Summary Statistics ==="

SUMMARY_FILE="$OUTPUT_DIR/benchmark_summary_${TIMESTAMP}.json"

STATIC_STATS=$(jq '.results | map(.static_app.total_response_time) | {
    avg: (add / length),
    min: min,
    max: max,
    count: length
}' $RESULTS_FILE)

VAULT_STATS=$(jq '.results | map(.vault_app.total_response_time) | {
    avg: (add / length),
    min: min, 
    max: max,
    count: length
}' $RESULTS_FILE)

OVERHEAD_STATS=$(jq '.results | map(.comparison.overhead_seconds) | {
    avg: (add / length),
    min: min,
    max: max
}' $RESULTS_FILE)

OVERHEAD_PERCENT_STATS=$(jq '.results | map(.comparison.overhead_percentage) | {
    avg: (add / length),
    min: min,
    max: max
}' $RESULTS_FILE)

ROTATION_STATS=$(jq '
  [.results[] | select(.rotation.performed == true and .rotation.duration_seconds != null) | .rotation.duration_seconds] as $durations |
  if ($durations | length) > 0 then {
    avg: ($durations | add / length),
    min: ($durations | min),
    max: ($durations | max),
    count: ($durations | length)
  } else {
    avg: null, 
    min: null, 
    max: null, 
    count: 0
  } end
' $RESULTS_FILE)

PERF_GRADE=$(echo "$OVERHEAD_PERCENT_STATS" | jq -r '
  .avg as $avg | 
  if $avg < 25 then "A - Excellent"
  elif $avg < 50 then "B - Good"
  elif $avg < 100 then "C - Acceptable"
  else "D - Needs Optimization"
  end
')

# Create summary with proper JSON structure
jq -n \
    --argjson iterations "$ITERATIONS" \
    --arg timestamp "$TIMESTAMP" \
    --arg test_date "$(date -Iseconds)" \
    --argjson static_stats "$STATIC_STATS" \
    --argjson vault_stats "$VAULT_STATS" \
    --argjson overhead_stats "$OVERHEAD_STATS" \
    --argjson overhead_percent_stats "$OVERHEAD_PERCENT_STATS" \
    --argjson rotation_stats "$ROTATION_STATS" \
    --arg perf_grade "$PERF_GRADE" \
    '{
        benchmark_info: {
            iterations: $iterations,
            timestamp: $timestamp,
            test_date: $test_date
        },
        statistics: {
            static_app: $static_stats,
            vault_app: $vault_stats,
            overhead: {
                absolute_seconds: $overhead_stats,
                percentage: $overhead_percent_stats
            },
            rotation_efficiency: $rotation_stats
        },
        recommendations: {
            acceptable_overhead_threshold: "< 50%",
            performance_grade: $perf_grade
        }
    }' > $SUMMARY_FILE

echo "=== Performance Report ==="
echo "Results saved to: $RESULTS_FILE"
echo "Summary saved to: $SUMMARY_FILE"

echo ""
echo "Key Performance Metrics:"
echo "========================"

# Safe output with null handling
jq -r 'if .statistics.static_app.avg then "Static App - Avg: " + (.statistics.static_app.avg | tostring) + "s, Min: " + (.statistics.static_app.min | tostring) + "s, Max: " + (.statistics.static_app.max | tostring) + "s" else "Static App - No data" end' $SUMMARY_FILE

jq -r 'if .statistics.vault_app.avg then "Vault App  - Avg: " + (.statistics.vault_app.avg | tostring) + "s, Min: " + (.statistics.vault_app.min | tostring) + "s, Max: " + (.statistics.vault_app.max | tostring) + "s" else "Vault App - No data" end' $SUMMARY_FILE

jq -r 'if .statistics.overhead.percentage.avg then "Overhead   - Avg: " + (.statistics.overhead.percentage.avg | tostring) + "%, Min: " + (.statistics.overhead.percentage.min | tostring) + "%, Max: " + (.statistics.overhead.percentage.max | tostring) + "%" else "Overhead - No data" end' $SUMMARY_FILE

jq -r 'if .statistics.rotation_efficiency.avg then "Rotation   - Avg: " + (.statistics.rotation_efficiency.avg | tostring) + "s, Count: " + (.statistics.rotation_efficiency.count | tostring) else "Rotation   - Count: " + (.statistics.rotation_efficiency.count | tostring) + " (No timing data)" end' $SUMMARY_FILE

jq -r '"Grade: " + .recommendations.performance_grade' $SUMMARY_FILE

CSV_FILE="$OUTPUT_DIR/benchmark_data_${TIMESTAMP}.csv"
echo "iteration,static_time,vault_time,overhead_seconds,overhead_percentage,rotation_performed,rotation_duration" > $CSV_FILE
jq -r '.results[] | [.iteration, .static_app.total_response_time, .vault_app.total_response_time, .comparison.overhead_seconds, .comparison.overhead_percentage, .rotation.performed, .rotation.duration_seconds] | @csv' $RESULTS_FILE >> $CSV_FILE

echo ""
echo "CSV data saved to: $CSV_FILE"
echo "Benchmark complete!"
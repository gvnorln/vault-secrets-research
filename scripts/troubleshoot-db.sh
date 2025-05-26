#!/bin/bash

echo "=== Database Connection Troubleshooting ==="

# Check PostgreSQL pod status
echo "[+] Checking PostgreSQL pod status..."
kubectl get pods -n database -o wide

echo "[+] Checking PostgreSQL service..."
kubectl get svc -n database

echo "[+] Checking PostgreSQL logs..."
kubectl logs -l app=postgres -n database --tail=20

# Test PostgreSQL connection directly
echo "[+] Testing direct PostgreSQL connection..."
kubectl exec -it $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -d testdb -c "SELECT version();"

# Test connection from a test pod
echo "[+] Creating test pod to check network connectivity..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: postgres-test
  namespace: database
spec:
  containers:
  - name: postgres-client
    image: postgres:13
    command: ['sleep', '3600']
  restartPolicy: Never
EOF

echo "Waiting for test pod to be ready..."
kubectl wait --for=condition=ready pod/postgres-test -n database --timeout=60s

echo "[+] Testing connection from test pod..."
kubectl exec -it postgres-test -n database -- psql -h postgres-service.database.svc.cluster.local -U postgres -d testdb -c "SELECT 'Connection successful!' as status;"

# Check if testdb exists
echo "[+] Checking if testdb database exists..."
kubectl exec -it $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -c "\l"

# Create testdb if it doesn't exist
echo "[+] Creating testdb if it doesn't exist..."
kubectl exec -it $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -c "CREATE DATABASE testdb;" || echo "Database might already exist"

# Create a test table
echo "[+] Creating test table..."
kubectl exec -it $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -d testdb -c "
CREATE TABLE IF NOT EXISTS test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_table (name) VALUES ('test1'), ('test2') ON CONFLICT DO NOTHING;
"

echo "[+] Checking test table..."
kubectl exec -it $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -d testdb -c "SELECT * FROM test_table;"

# Cleanup test pod
echo "[+] Cleaning up test pod..."
kubectl delete pod postgres-test -n database --ignore-not-found=true

echo "=== Troubleshooting completed ==="
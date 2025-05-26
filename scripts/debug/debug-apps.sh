#!/bin/bash

echo "=== Quick Debug for Database Connection ==="

# Function untuk check logs aplikasi
check_logs() {
    echo "=== Checking Application Logs ==="
    echo "Static app logs:"
    kubectl logs deployment/static-secrets-app --tail=10
    echo -e "\nVault app logs:"
    kubectl logs deployment/vault-secrets-app --tail=10
}

# Function untuk check database
check_database() {
    echo "=== Checking Database ==="
    echo "Database pods:"
    kubectl get pods -n database
    
    echo -e "\nTesting database connection:"
    kubectl run --rm -i --tty db-test --image=postgres:15 --restart=Never -- \
        sh -c "PGPASSWORD=initialpassword123 psql -h postgres-service.database.svc.cluster.local -U postgres -d testdb -c 'SELECT COUNT(*) FROM users;'" 2>/dev/null || echo "Database connection failed"
}

# Function untuk create sample data
create_sample_data() {
    echo "=== Creating Sample Data ==="
    kubectl run --rm -i --tty create-data --image=postgres:15 --restart=Never -- \
        sh -c "PGPASSWORD=initialpassword123 psql -h postgres-service.database.svc.cluster.local -U postgres -d testdb -c \"
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(100) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            INSERT INTO users (username, email) VALUES 
            ('alice', 'alice@example.com'),
            ('bob', 'bob@example.com'),
            ('charlie', 'charlie@example.com')
            ON CONFLICT (username) DO NOTHING;
            SELECT COUNT(*) as user_count FROM users;
        \"" 2>/dev/null || echo "Failed to create sample data"
}

# Function untuk test ulang
test_again() {
    echo "=== Testing Applications Again ==="
    
    # Test static app
    kubectl port-forward svc/static-secrets-service 8080:5000 &
    STATIC_PID=$!
    sleep 3
    
    echo "Static app users:"
    curl -s http://localhost:8080/users | jq '.users // .error' 2>/dev/null || echo "Request failed"
    
    kill $STATIC_PID 2>/dev/null
    sleep 2
    
    # Test vault app
    kubectl port-forward svc/vault-secrets-service 8081:5000 &
    VAULT_PID=$!
    sleep 3
    
    echo "Vault app users:"
    curl -s http://localhost:8081/users | jq '.users // .error' 2>/dev/null || echo "Request failed"
    
    kill $VAULT_PID 2>/dev/null
}

# Main execution
check_logs
check_database
create_sample_data
test_again

echo "=== Debug completed ==="

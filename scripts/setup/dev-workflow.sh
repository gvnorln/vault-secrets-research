#!/bin/bash

ACTION=${1:-"help"}

case $ACTION in
    "start")
        echo "🚀 Starting development environment..."
        minikube start --driver=docker --memory=4096 --cpus=2
        kubectl apply -f k8s/postgres/
        kubectl apply -f k8s/vault/
        echo "✅ Infrastructure deployed"
        echo "Run: ./scripts/dev-workflow.sh build"
        ;;
        
    "build")
        echo "🔨 Building applications..."
        eval $(minikube docker-env)
        cd test-apps/static-secrets-app && docker build -t static-secrets-app:dev . && cd ../..
        cd test-apps/vault-secrets-app && docker build -t vault-secrets-app:dev . && cd ../..
        echo "✅ Applications built"
        echo "Run: ./scripts/dev-workflow.sh deploy"
        ;;
        
    "deploy")
        echo "📦 Deploying applications..."
        if [ ! -f vault-init-keys.txt ]; then
            echo "⚠️  Vault not initialized. Run: ./scripts/dev-workflow.sh init-vault"
            exit 1
        fi
        ROOT_TOKEN=$(grep 'Initial Root Token:' vault-init-keys.txt | awk '{print $NF}')
        kubectl apply -f k8s/app/static-secrets-deployment.yaml
        sed "s/REPLACE_WITH_ROOT_TOKEN/$ROOT_TOKEN/g" k8s/app/vault-secrets-deployment.yaml | kubectl apply -f -
        echo "✅ Applications deployed"
        echo "Run: ./scripts/dev-workflow.sh test"
        ;;
        
    "init-vault")
        echo "🔐 Initializing Vault..."
        kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s
        kubectl port-forward svc/vault-service 8200:8200 -n vault &
        PF_PID=$!
        sleep 10
        
        export VAULT_ADDR="http://localhost:8200"
        vault operator init -key-shares=5 -key-threshold=3 > vault-init-keys.txt
        
        # Extract and unseal
        UNSEAL_KEY_1=$(grep 'Unseal Key 1:' vault-init-keys.txt | awk '{print $NF}')
        UNSEAL_KEY_2=$(grep 'Unseal Key 2:' vault-init-keys.txt | awk '{print $NF}')
        UNSEAL_KEY_3=$(grep 'Unseal Key 3:' vault-init-keys.txt | awk '{print $NF}')
        ROOT_TOKEN=$(grep 'Initial Root Token:' vault-init-keys.txt | awk '{print $NF}')
        
        vault operator unseal $UNSEAL_KEY_1
        vault operator unseal $UNSEAL_KEY_2
        vault operator unseal $UNSEAL_KEY_3
        
        # Configure
        vault auth $ROOT_TOKEN
        vault secrets enable database
        vault write database/config/postgres \
            plugin_name=postgresql-database-plugin \
            connection_url="postgresql://{{username}}:{{password}}@postgres-service.database.svc.cluster.local:5432/testdb?sslmode=disable" \
            allowed_roles="readonly,readwrite" \
            username="postgres" \
            password="initialpassword123"
        
        vault write database/roles/readonly \
            db_name=postgres \
            creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
            default_ttl="1h" \
            max_ttl="24h"
            
        vault write database/roles/readwrite \
            db_name=postgres \
            creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
            default_ttl="1h" \
            max_ttl="24h"
        
        kill $PF_PID
        echo "✅ Vault initialized and configured"
        ;;
        
    "test")
        echo "🧪 Running tests..."
        kubectl port-forward svc/static-secrets-service 8080:5000 &
        STATIC_PID=$!
        kubectl port-forward svc/vault-secrets-service 8081:5000 &
        VAULT_PID=$!
        sleep 10
        
        echo "Testing static app..."
        curl -s http://localhost:8080/health | jq .
        
        echo "Testing vault app..."
        curl -s http://localhost:8081/health | jq .
        
        echo "Performance comparison..."
        echo "Static response time:"
        time curl -s http://localhost:8080/users > /dev/null
        echo "Vault response time:"
        time curl -s http://localhost:8081/users > /dev/null
        
        kill $STATIC_PID $VAULT_PID
        echo "✅ Tests completed"
        ;;
        
    "benchmark")
        echo "📊 Running performance benchmark..."
        ./scripts/performance-benchmark.sh ${2:-20}
        ;;
        
    "clean")
        echo "🧹 Cleaning up..."
        kubectl delete -f k8s/app/ 2>/dev/null || true
        kubectl delete -f k8s/vault/ 2>/dev/null || true
        kubectl delete -f k8s/postgres/ 2>/dev/null || true
        docker system prune -f
        echo "✅ Cleanup completed"
        ;;
        
    "stop")
        echo "⏹️  Stopping development environment..."
        minikube stop
        echo "✅ Environment stopped"
        ;;
        
    "status")
        echo "📋 Environment status:"
        echo "Minikube: $(minikube status | grep host | awk '{print $2}')"
        echo "Kubernetes nodes:"
        kubectl get nodes 2>/dev/null || echo "  Not available"
        echo "Pods:"
        kubectl get pods --all-namespaces 2>/dev/null || echo "  Not available"
        ;;
        
    "help"|*)
        echo "🚀 Vault Secrets Research Development Workflow"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start       - Start minikube and deploy infrastructure"
        echo "  init-vault  - Initialize and configure Vault"
        echo "  build       - Build application Docker images"
        echo "  deploy      - Deploy applications to Kubernetes"
        echo "  test        - Run basic functionality tests"
        echo "  benchmark   - Run performance benchmark"
        echo "  status      - Show environment status"
        echo "  clean       - Clean up all resources"
        echo "  stop        - Stop minikube"
        echo "  help        - Show this help"
        echo ""
        echo "Quick Start:"
        echo "  $0 start && $0 init-vault && $0 build && $0 deploy && $0 test"
        ;;
esac
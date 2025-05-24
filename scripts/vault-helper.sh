#!/bin/bash

VAULT_NAMESPACE="vault"
VAULT_SERVICE="vault-service"
VAULT_PORT="8200"
KEYS_FILE="$HOME/vault-secrets-research/vault-init-keys.txt"

# Function to check if port is available
check_port() {
    if lsof -Pi :$VAULT_PORT -sTCP:LISTEN -t >/dev/null ; then
        echo "Port $VAULT_PORT is already in use. Cleaning up..."
        sudo lsof -ti:$VAULT_PORT | xargs -r kill -9
        sleep 3
    fi
}

case "$1" in
    "unseal")
        check_port
        ./scripts/vault-unseal.sh
        ;;
    "status")
        check_port
        kubectl port-forward svc/$VAULT_SERVICE $VAULT_PORT:$VAULT_PORT -n $VAULT_NAMESPACE &
        PF_PID=$!
        sleep 10
        export VAULT_ADDR="http://localhost:$VAULT_PORT"
        vault status
        kill $PF_PID 2>/dev/null
        ;;
    "connect")
        check_port
        echo "Starting port forward to Vault..."
        echo "Vault will be available at http://localhost:$VAULT_PORT"
        kubectl port-forward svc/$VAULT_SERVICE $VAULT_PORT:$VAULT_PORT -n $VAULT_NAMESPACE
        ;;
    "login")
        if [ -f "$KEYS_FILE" ]; then
            ROOT_TOKEN=$(grep 'Initial Root Token:' $KEYS_FILE | awk '{print $NF}')
            export VAULT_ADDR="http://localhost:$VAULT_PORT"
            vault login $ROOT_TOKEN
            echo "Logged in with root token successfully"
        else
            echo "Keys file not found: $KEYS_FILE"
        fi
        ;;
    "logs")
        kubectl logs -l app=vault -n $VAULT_NAMESPACE -f
        ;;
    "pod-status")
        echo "=== Vault Pod Status ==="
        kubectl get pods -n $VAULT_NAMESPACE
        kubectl get svc -n $VAULT_NAMESPACE
        kubectl get pvc -n $VAULT_NAMESPACE
        ;;
    "cleanup")
        echo "Cleaning up port forwards..."
        sudo lsof -ti:$VAULT_PORT | xargs -r kill -9
        pkill -f "kubectl port-forward.*vault"
        ;;
    *)
        echo "Usage: $0 {unseal|status|connect|login|logs|pod-status|cleanup}"
        echo "  unseal     - Unseal Vault after restart"
        echo "  status     - Check Vault status"
        echo "  connect    - Port forward to Vault"
        echo "  login      - Login with root token"
        echo "  logs       - Show Vault logs"
        echo "  pod-status - Show pod status"
        echo "  cleanup    - Clean up port forwards"
        ;;
esac

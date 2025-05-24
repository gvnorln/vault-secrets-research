#!/bin/bash

DB_NAMESPACE="database"
DB_SERVICE="postgres-service"
DB_PORT="5432"

case "$1" in
    "connect")
        kubectl port-forward svc/$DB_SERVICE $DB_PORT:$DB_PORT -n $DB_NAMESPACE
        ;;
    "logs")
        kubectl logs -l app=postgres -n $DB_NAMESPACE -f
        ;;
    "shell")
        kubectl exec -it $(kubectl get pod -l app=postgres -n $DB_NAMESPACE -o jsonpath='{.items[0].metadata.name}') -n $DB_NAMESPACE -- bash
        ;;
    "psql")
        kubectl exec -it $(kubectl get pod -l app=postgres -n $DB_NAMESPACE -o jsonpath='{.items[0].metadata.name}') -n $DB_NAMESPACE -- psql -U postgres -d testdb
        ;;
    "status")
        echo "=== Database Status ==="
        kubectl get pods -n $DB_NAMESPACE
        kubectl get svc -n $DB_NAMESPACE
        kubectl get pvc -n $DB_NAMESPACE
        ;;
    *)
        echo "Usage: $0 {connect|logs|shell|psql|status}"
        echo "  connect  - Port forward database"
        echo "  logs     - Show database logs"
        echo "  shell    - Access database container shell"
        echo "  psql     - Access PostgreSQL CLI"
        echo "  status   - Show database status"
        ;;
esac

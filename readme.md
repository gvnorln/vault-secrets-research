# Enable database secrets engine

vault secrets enable database

# Check if enabled

vault secrets list

# Ensure testdb exists

kubectl exec $(kubectl get pod -l app=postgres -n database -o jsonpath='{.items[0].metadata.name}') -n database -- psql -U postgres -c "CREATE DATABASE testdb;"

# Configure database connection

vault write database/config/postgres \
 plugin_name=postgresql-database-plugin \
 connection_url="postgresql://{{username}}:{{password}}@postgres-service.database.svc.cluster.local:5432/testdb?sslmode=disable" \
 allowed_roles="readonly,readwrite" \
 username="postgres" \
 password="initialpassword123"

# Create roles

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

# Test credential generation

vault read database/creds/readonly
vault read database/creds/readwrite

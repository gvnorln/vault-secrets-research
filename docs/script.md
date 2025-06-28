kubectl cp vault/vault-549f7d65-ppjk8:/vault/logs/audit.log ./audit.log
jq '.' audit.log | less

## liat user dan password

vault read database/creds/readonly
vault read database/creds/readwrite

#!/usr/bin/env bash
# Nur für DEV (Vault dev-mode).
set -euo pipefail
VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
VAULT_TOKEN=${VAULT_TOKEN:-root-dev-token}

export VAULT_ADDR VAULT_TOKEN

echo "[*] Enable KV"
vault secrets enable -path=kv kv-v2 || true

echo "[*] Put sample secret"
vault kv put kv/app api_token="REPLACE_ME_DEV" classification_default="internal"

echo "[*] Enable Transit"
vault secrets enable transit || true
vault write transit/keys/ledger-sign type=ed25519 allow_plaintext_backup=true || true
vault write transit/keys/doc-bytes type=aes256-gcm96 || true

echo "[*] Enable Database Engine"
vault secrets enable database || true
vault write database/config/pg-nlp \
  plugin_name="postgresql-database-plugin" \
  allowed_roles="docproc-db-role" \
  connection_url="postgresql://{{username}}:{{password}}@pg:5432/nlpdb?sslmode=disable" \
  username="nlp" \
  password="ChangeMeStrong!"

vault write database/roles/docproc-db-role \
  db_name=pg-nlp \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE nlpdb TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="6h"

echo "[*] Enable AppRole"
vault auth enable approle || true

echo "[*] Create/Update Policies"
vault policy write kv-app vault/policies/kv-app.hcl
vault policy write transit-ledger vault/policies/transit-ledger.hcl
vault policy write db-dynamic vault/policies/db-dynamic.hcl

echo "[*] Create AppRole: docproc"
vault write auth/approle/role/docproc-role \
  token_policies="kv-app,transit-ledger,db-dynamic" \
  token_ttl=1h token_max_ttl=4h \
  secret_id_ttl=24h secret_id_num_uses=10

echo "[*] Create AppRole: ipguard (nur sign/verify)"
vault write auth/approle/role/ipguard-role \
  token_policies="transit-ledger" \
  token_ttl=1h token_max_ttl=4h

echo "[*] Create AppRole: gateway (nur kv read)"
vault write auth/approle/role/gateway-role \
  token_policies="kv-app" \
  token_ttl=30m token_max_ttl=2h

echo "[*] Fetch Role IDs (store locally - DO NOT COMMIT real secrets)"
vault read -field=role_id auth/approle/role/docproc-role/role-id > vault/runtime/docproc/role_id
vault read -field=role_id auth/approle/role/ipguard-role/role-id > vault/runtime/ipguard/role_id
vault read -field=role_id auth/approle/role/gateway-role/role-id > vault/runtime/gateway/role_id

echo "[*] Generate Secret IDs (DEV ONLY!)"
vault write -field=secret_id auth/approle/role/docproc-role/secret-id > vault/runtime/docproc/secret_id
vault write -field=secret_id auth/approle/role/ipguard-role/secret-id > vault/runtime/ipguard/secret_id
vault write -field=secret_id auth/approle/role/gateway-role/secret-id > vault/runtime/gateway/secret_id

echo "[*] Done - DO NOT COMMIT vault/runtime/ with real credentials."

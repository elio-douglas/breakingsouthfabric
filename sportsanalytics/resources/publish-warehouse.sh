#!/usr/bin/env bash
# Builds and publishes the sportsanalytics-dwh SQL project (dacpac) to the Fabric Data Warehouse.
#
# Usage:
#   ./publish-warehouse.sh
#   DRY_RUN=1 ./publish-warehouse.sh
#
# Optional env vars:
#   SQL_DATABASE   target warehouse (default: sportsanalytics-dwh)
#   SQLPROJ        path to the .sqlproj (default below)
#   KEY_VAULT      Key Vault holding the service principal secrets (default: breakingsouthkv)
#   DRY_RUN=1      generate the deployment script instead of applying it
#   BREAKINGSOUTH_TENANT_ID / BREAKINGSOUTH_CLIENT_ID / BREAKINGSOUTH_CLIENT_SECRET
#                  service principal credentials; any not set are read from Key Vault
#                  (sp-sportsanalytics-admin-tenant / -client / -secret)
#
# Auth: service principal (client credentials) Entra access token.
# Requires: dotnet SDK, curl, jq, Azure CLI with an `az login` session (only for Key Vault lookups),
# sqlpackage (installed as a dotnet tool if missing).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQLPROJ="${SQLPROJ:-$SCRIPT_DIR/../workspace/sportsanalytics-dwh.Warehouse/sportsanalytics-dwh.sqlproj}"
SQL_DATABASE="${SQL_DATABASE:-sportsanalytics-dwh}"
SQL_SERVER="nkc3sqzhtfweramv3d7c4re6ja-z6qm4eqwcuauhaj54jrjaawvam.datawarehouse.fabric.microsoft.com"
KEY_VAULT="${KEY_VAULT:-breakingsouthkv}"

TENANT_ID="${BREAKINGSOUTH_TENANT_ID:-}"
CLIENT_ID="${BREAKINGSOUTH_CLIENT_ID:-}"
CLIENT_SECRET="${BREAKINGSOUTH_CLIENT_SECRET:-}"

[[ -f "$SQLPROJ" ]] || { echo "sqlproj not found: $SQLPROJ" >&2; exit 1; }
SQLPROJ="$(cd "$(dirname "$SQLPROJ")" && pwd)/$(basename "$SQLPROJ")"

command -v dotnet >/dev/null || { echo "dotnet SDK is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
if [[ -z "$TENANT_ID" || -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  command -v az >/dev/null || { echo "Azure CLI (az) is required to read secrets from Key Vault" >&2; exit 1; }
fi

if ! command -v sqlpackage >/dev/null; then
  echo "Installing sqlpackage as a global dotnet tool..."
  dotnet tool install --global microsoft.sqlpackage
  export PATH="$PATH:$HOME/.dotnet/tools"
fi

kv_secret() {
  az keyvault secret show --vault-name "$KEY_VAULT" --name "$1" --query value -o tsv
}

if [[ -z "$TENANT_ID" || -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  echo "Reading service principal credentials from Key Vault $KEY_VAULT..."
  [[ -n "$TENANT_ID" ]] || TENANT_ID="$(kv_secret sp-sportsanalytics-admin-tenant)"
  [[ -n "$CLIENT_ID" ]] || CLIENT_ID="$(kv_secret sp-sportsanalytics-admin-client)"
  [[ -n "$CLIENT_SECRET" ]] || CLIENT_SECRET="$(kv_secret sp-sportsanalytics-admin-secret)"
fi

PROJECT_DIR="$(dirname "$SQLPROJ")"
PROJECT_NAME="$(basename "$SQLPROJ" .sqlproj)"
DACPAC="$PROJECT_DIR/bin/Release/$PROJECT_NAME.dacpac"

echo "Building $SQLPROJ..."
dotnet build "$SQLPROJ" -c Release

[[ -f "$DACPAC" ]] || { echo "dacpac not found after build: $DACPAC" >&2; exit 1; }

echo "Getting Entra access token for service principal $CLIENT_ID..."
# Secret is passed on stdin so it doesn't show up in the process list.
ACCESS_TOKEN="$(printf '%s' "$CLIENT_SECRET" | curl -sS -X POST \
  "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret@-" \
  --data-urlencode "scope=https://database.windows.net/.default" \
  | jq -r '.access_token // empty')"
[[ -n "$ACCESS_TOKEN" ]] || { echo "Failed to get service principal access token." >&2; exit 1; }

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  OUT="$PROJECT_DIR/bin/Release/$PROJECT_NAME.deploy.sql"
  echo "Dry run: generating deployment script at $OUT"
  sqlpackage /Action:Script \
    /SourceFile:"$DACPAC" \
    /TargetServerName:"$SQL_SERVER" \
    /TargetDatabaseName:"$SQL_DATABASE" \
    /AccessToken:"$ACCESS_TOKEN" \
    /OutputPath:"$OUT" \
    /p:BlockOnPossibleDataLoss=true
  exit 0
fi

echo "Publishing $PROJECT_NAME to $SQL_SERVER/$SQL_DATABASE..."
sqlpackage /Action:Publish \
  /SourceFile:"$DACPAC" \
  /TargetServerName:"$SQL_SERVER" \
  /TargetDatabaseName:"$SQL_DATABASE" \
  /AccessToken:"$ACCESS_TOKEN" \
  /p:BlockOnPossibleDataLoss=true

echo "Published."

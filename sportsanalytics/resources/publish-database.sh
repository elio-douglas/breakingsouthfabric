#!/usr/bin/env bash
# Builds and publishes the sportsanalytics SQL project (dacpac) to Azure SQL.
#
# Usage:
#   SQL_SERVER=<server>.database.windows.net ./publish-database.sh
#
# Optional env vars:
#   SQL_DATABASE   target database (default: sportsanalytics)
#   SQLPROJ        path to the .sqlproj (default below)
#   DRY_RUN=1      generate the deployment script instead of applying it
#
# Auth: uses your current `az login` session (Entra access token).
# Requires: dotnet SDK, Azure CLI, sqlpackage (installed as a dotnet tool if missing).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQLPROJ="${SQLPROJ:-$SCRIPT_DIR/../db/sportsanalytics/sportsanalytics.sqlproj}"
SQL_DATABASE="${SQL_DATABASE:-sportsanalytics}"
: "${SQL_SERVER:?Set SQL_SERVER, e.g. myserver.database.windows.net}"

[[ -f "$SQLPROJ" ]] || { echo "sqlproj not found: $SQLPROJ" >&2; exit 1; }
command -v az >/dev/null || { echo "Azure CLI (az) is required" >&2; exit 1; }
command -v dotnet >/dev/null || { echo "dotnet SDK is required" >&2; exit 1; }

if ! command -v sqlpackage >/dev/null; then
  echo "Installing sqlpackage as a global dotnet tool..."
  dotnet tool install --global microsoft.sqlpackage
  export PATH="$PATH:$HOME/.dotnet/tools"
fi

PROJECT_DIR="$(dirname "$SQLPROJ")"
PROJECT_NAME="$(basename "$SQLPROJ" .sqlproj)"
DACPAC="$PROJECT_DIR/bin/Release/$PROJECT_NAME.dacpac"

echo "Building $SQLPROJ..."
dotnet build "$SQLPROJ" -c Release

[[ -f "$DACPAC" ]] || { echo "dacpac not found after build: $DACPAC" >&2; exit 1; }

echo "Getting Entra access token..."
ACCESS_TOKEN="$(az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv)"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  OUT="$PROJECT_DIR/bin/Release/$PROJECT_NAME.deploy.sql"
  echo "Dry run: generating deployment script at $OUT"
  sqlpackage /Action:Script \
    /SourceFile:"$DACPAC" \
    /TargetServerName:"$SQL_SERVER" \
    /TargetDatabaseName:"$SQL_DATABASE" \
    /AccessToken:"$ACCESS_TOKEN" \
    /OutputPath:"$OUT"
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

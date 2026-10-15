#!/usr/bin/env bash
# Shows how much of the Azure SQL Database free offer (100,000 vCore seconds/month)
# has been used this month, plus the free-offer settings of the database.
#
# Usage:
#   ./free-tier-usage.sh
#
# Optional env vars (defaults match this project):
#   RESOURCE_GROUP (personal)  SQL_SERVER_NAME (breakingsouth)  SQL_DATABASE (sportsanalytics)
#   INTERVAL       metric grain, ISO 8601 (default P1D; use PT1H for hourly)
#
# Requires: Azure CLI (logged in) and python3.

set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-personal}"
SQL_SERVER_NAME="${SQL_SERVER_NAME:-breakingsouth}"
SQL_DATABASE="${SQL_DATABASE:-sportsanalytics}"
INTERVAL="${INTERVAL:-P1D}"
ALLOWANCE=100000

command -v az >/dev/null || { echo "Azure CLI (az) is required" >&2; exit 1; }

DB_ID="$(az sql db show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE" --query id -o tsv)"

echo "== Free offer settings =="
az sql db show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE" \
  --query "{useFreeLimit:useFreeLimit, whenExhausted:freeLimitExhaustionBehavior, autoPauseDelayMin:autoPauseDelay, status:status}" \
  -o table

START="$(date -u +%Y-%m-01T00:00:00Z)"
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo
echo "== vCore seconds this month (since $START) =="
az monitor metrics list \
  --resource "$DB_ID" \
  --metric free_amount_remaining free_amount_consumed \
  --aggregation Minimum Maximum \
  --interval "$INTERVAL" \
  --start-time "$START" --end-time "$END" \
  -o json |
ALLOWANCE="$ALLOWANCE" python3 -c '
import json, os, sys

allowance = int(os.environ["ALLOWANCE"])
data = json.load(sys.stdin)
series = {}
for m in data.get("value", []):
    pts = m["timeseries"][0]["data"] if m["timeseries"] else []
    series[m["name"]["value"]] = pts

remaining = [p["minimum"] for p in series.get("free_amount_remaining", []) if p.get("minimum") is not None]
consumed = [p["maximum"] for p in series.get("free_amount_consumed", []) if p.get("maximum") is not None]

if not remaining and not consumed:
    print("No metric data yet this month (the database may not have been active, or metrics are delayed).")
    sys.exit(0)

rem = remaining[-1] if remaining else allowance - consumed[-1]
used = consumed[-1] if consumed else allowance - rem
print(f"Used:      {used:>10,.0f} vCore seconds ({used / allowance:.1%})")
print(f"Remaining: {rem:>10,.0f} vCore seconds ({rem / allowance:.1%})")
print()
print("Per-interval remaining:")
for p in series.get("free_amount_remaining", []):
    if p.get("minimum") is not None:
        ts, val = p["timeStamp"], p["minimum"]
        print(f"  {ts}  {val:>10,.0f}")
'

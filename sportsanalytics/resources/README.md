# sportsanalytics resources

Scripts, configuration and notebooks supporting the sportsanalytics
workspace. Migrated from the former `breakingsouthsportsanalytics`
repository.

## Contents

- `api-config.csv` — API-Football endpoints to extract, by stage.
- `deploy-config.py` — uploads `api-config.csv` to the `sportsanalytics`
  blob container.
- `football-analytics.ipynb` — extraction and modeling notebook
  (DuckDB → Azure SQL).
- `publish-database.sh` — builds and publishes `../db/sportsanalytics`
  to Azure SQL.
- `publish-warehouse.sh` / `publish-warehouse.ps1` — builds and
  publishes the Fabric warehouse project.
- `free-tier-usage.sh` — Azure SQL free-offer vCore usage this month.
- `verify-sp-permissions.sql` — lists the service principal's permissions
  and role memberships on the Azure SQL database (declared in
  `../db/sportsanalytics/Security/`).
- `breakingsouth.json` — Power BI report theme.

## Docs

- [Connecting duckdb to Fabric Azure SQL Database](https://hugr-lab.github.io/mssql-extension/connection/azure/)

-- Service principal used by the football notebook (DuckDB mssql extension) to load data.
-- The name must match the service principal's app registration display name.
CREATE USER [sportsanalytics-admin] FROM EXTERNAL PROVIDER;
GO

-- Data access scoped to the football schema; table structure is owned by this project.
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[football] TO [sportsanalytics-admin];
GO

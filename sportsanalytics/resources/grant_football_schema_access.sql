-- Run against the `sportsanalytics` database as an Entra admin / db_owner.
-- Grants the service principal read/write/DDL access scoped to the football schema only.

-- 1. Create the database user for the service principal (skip if it already exists).
--    The name must match the service principal's app registration display name.
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'sportsanalytics-admin')
    CREATE USER [sportsanalytics-admin] FROM EXTERNAL PROVIDER;
GO

-- 2. Data access on the football schema.
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::football TO [sportsanalytics-admin];
GO

-- 3. DDL, needed for CREATE OR REPLACE TABLE / DROP TABLE from DuckDB.
GRANT CREATE TABLE TO [sportsanalytics-admin];       -- database-level permission
GRANT ALTER ON SCHEMA::football TO [sportsanalytics-admin];
GO

-- 4. Bulk loads (DuckDB uses the BCP protocol for CREATE TABLE AS / COPY).
GRANT ADMINISTER DATABASE BULK OPERATIONS TO [sportsanalytics-admin];
GO

-- Verify
SELECT
    pr.name AS principal,
    pe.permission_name,
    pe.state_desc,
    COALESCE(s.name, '(database)') AS schema_name
FROM sys.database_permissions AS pe
    INNER JOIN sys.database_principals AS pr ON pe.grantee_principal_id = pr.principal_id
    LEFT JOIN sys.schemas AS s ON pe.class = 3 AND pe.major_id = s.schema_id
WHERE pr.name = N'sportsanalytics-admin';

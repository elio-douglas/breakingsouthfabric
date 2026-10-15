-- Run against the `sportsanalytics` database to list the permissions and role
-- memberships held by the service principal. Its access is declared in
-- ../db/sportsanalytics/Security/sportsanalytics-admin.sql and deployed by publish-database.sh.

SELECT
    pr.name AS principal,
    pe.permission_name,
    pe.state_desc,
    COALESCE(s.name, '(database)') AS schema_name
FROM sys.database_permissions AS pe
    INNER JOIN sys.database_principals AS pr ON pe.grantee_principal_id = pr.principal_id
    LEFT JOIN sys.schemas AS s ON pe.class = 3 AND pe.major_id = s.schema_id
WHERE pr.name = N'sportsanalytics-admin';

SELECT
    r.name AS role_name
FROM sys.database_role_members AS rm
    INNER JOIN sys.database_principals AS r ON rm.role_principal_id = r.principal_id
    INNER JOIN sys.database_principals AS m ON rm.member_principal_id = m.principal_id
WHERE m.name = N'sportsanalytics-admin';

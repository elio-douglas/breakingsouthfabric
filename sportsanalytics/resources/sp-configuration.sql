CREATE USER [sportsanalytics-admin] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datawriter ADD MEMBER [sportsanalytics-admin];
ALTER ROLE db_datareader ADD MEMBER [sportsanalytics-admin];
CREATE TABLE [football].[countries]
(
  [id] INT NOT NULL,
  [code] VARCHAR(10) NOT NULL,
  [name] VARCHAR(100) NOT NULL,
  [flag] VARCHAR(255) NOT NULL,
  [valid_from] DATE NOT NULL DEFAULT '1900-01-01',
  [valid_to] DATE NOT NULL DEFAULT '9999-12-31',
  [is_current] BIT NOT NULL DEFAULT 1,
  CONSTRAINT PK_countries PRIMARY KEY ([id])
)

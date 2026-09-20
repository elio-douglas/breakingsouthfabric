CREATE TABLE [football].[leagues]
(
  [id] INT NOT NULL PRIMARY KEY,
  [name] VARCHAR(100) NOT NULL,
  [type] VARCHAR(50) NOT NULL,
  [logo] VARCHAR(255) NOT NULL,
  [country_id] INT NOT NULL,
  [valid_from] DATE NOT NULL DEFAULT '1900-01-01',
  [valid_to] DATE NOT NULL DEFAULT '9999-12-31',
  [is_current] BIT NOT NULL DEFAULT 1,
  CONSTRAINT FK_leagues_country FOREIGN KEY ([country_id]) REFERENCES [football].[countries]([id])
)

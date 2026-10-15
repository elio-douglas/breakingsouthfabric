CREATE TABLE [football].[venues]
(
  [id] INT NOT NULL PRIMARY KEY,
  [name] NVARCHAR(255) NOT NULL,
  [city] NVARCHAR(255) NULL,
  [capacity] INT NULL,
  [surface] NVARCHAR(255) NULL,
  [address] NVARCHAR(510) NULL,
  [image] NVARCHAR(510) NULL,
  [is_current] BIT NOT NULL DEFAULT 1,
  [valid_from] DATE NOT NULL DEFAULT '1900-01-01',
  [valid_to] DATE NOT NULL DEFAULT '9999-12-31'
)

CREATE TABLE [football].[teams]
(
  [id] INT NOT NULL PRIMARY KEY,
  [code] NVARCHAR(50) NULL,
  [name] NVARCHAR(255) NOT NULL,
  [logo] NVARCHAR(510) NULL,
  [is_national] BIT NULL,
  [venue_id] INT NULL,
  [is_current] BIT NOT NULL DEFAULT 1,
  [valid_from] DATE NOT NULL DEFAULT '1900-01-01',
  [valid_to] DATE NOT NULL DEFAULT '9999-12-31',
  CONSTRAINT [FK_teams_venue_id] FOREIGN KEY ([venue_id]) REFERENCES [football].[venues]([id])
)

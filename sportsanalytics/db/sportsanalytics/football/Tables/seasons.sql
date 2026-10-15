CREATE TABLE [football].[seasons]
(
  [id] INT NOT NULL PRIMARY KEY,
  [league_id] INT NOT NULL,
  [start] DATE NOT NULL,
  [end] DATE NOT NULL,
  [is_current] BIT NOT NULL DEFAULT 1,
  [valid_from] DATE NOT NULL DEFAULT '1900-01-01',
  [valid_to] DATE NOT NULL DEFAULT '9999-12-31',
  CONSTRAINT [FK_seasons_league_id] FOREIGN KEY ([league_id]) REFERENCES [football].[leagues]([id])
)

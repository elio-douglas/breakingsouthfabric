CREATE TABLE [football].[events]
(
  [id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  [fixture_id] INT NOT NULL,
  [minute_id] INT NOT NULL,
  [team_id] INT NOT NULL,
  [player_id] INT NOT NULL,
  [player_out_id] INT NULL,
  [event_type_id] INT NOT NULL,
  CONSTRAINT [FK_events_fixture_id] FOREIGN KEY ([fixture_id]) REFERENCES [football].[fixtures]([id]),
  CONSTRAINT [FK_events_team_id] FOREIGN KEY ([team_id]) REFERENCES [football].[teams]([id]),
  CONSTRAINT [FK_events_event_type_id] FOREIGN KEY ([event_type_id]) REFERENCES [football].[event_types]([id])
)

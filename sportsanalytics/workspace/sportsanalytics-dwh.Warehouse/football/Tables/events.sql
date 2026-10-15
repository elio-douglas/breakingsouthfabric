CREATE TABLE [football].[events] (
    [id]            BIGINT IDENTITY NOT NULL,
    [fixture_id]    INT    NOT NULL,
    [minute_id]     INT    NOT NULL,
    [team_id]       INT    NOT NULL,
    [player_id]     INT    NOT NULL,
    [player_out_id] INT    NULL,
    [event_type_id] INT    NOT NULL
);


GO
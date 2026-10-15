CREATE TABLE [football].[fixtures] (
    [id]             INT      NULL,
    [date_id]        INT      NOT NULL,
    [time_id]        SMALLINT NOT NULL,
    [league_id]      INT      NOT NULL,
    [home_team_id]   INT      NOT NULL,
    [away_team_id]   INT      NOT NULL,
    [halftime_home]  SMALLINT NOT NULL,
    [halftime_away]  SMALLINT NOT NULL,
    [fulltime_home]  SMALLINT NOT NULL,
    [fulltime_away]  SMALLINT NOT NULL,
    [extratime_home] SMALLINT NULL,
    [extratime_away] SMALLINT NULL,
    [penalty_home]   SMALLINT NULL,
    [penalty_away]   SMALLINT NULL
);


GO
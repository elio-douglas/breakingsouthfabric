CREATE TABLE [football].[seasons] (
    [id]        INT  NOT NULL,
    [league_id] INT  NOT NULL,
    [start]     DATE NOT NULL,
    [end]       DATE NOT NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO
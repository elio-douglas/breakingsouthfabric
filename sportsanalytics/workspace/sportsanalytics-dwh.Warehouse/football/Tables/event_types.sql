CREATE TABLE [football].[event_types] (
    [id]       INT           NOT NULL,
    [type]     VARCHAR (255) NOT NULL,
    [detail]   VARCHAR (255) NOT NULL,
    [comments] VARCHAR (255) NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO
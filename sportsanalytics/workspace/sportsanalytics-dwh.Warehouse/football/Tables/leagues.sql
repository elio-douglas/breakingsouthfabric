CREATE TABLE [football].[leagues] (
    [id]         INT           NOT NULL,
    [code]       INT           NULL,
    [name]       VARCHAR (100) NOT NULL,
    [type]       VARCHAR (50)  NOT NULL,
    [logo]       VARCHAR (255) NULL,
    [country_id] INT           NOT NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO
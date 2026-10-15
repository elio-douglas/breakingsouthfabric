CREATE TABLE [football].[teams] (
    [id]          INT           NOT NULL,
    [code]        VARCHAR (50)  NULL,
    [name]        VARCHAR (255) NOT NULL,
    [logo]        VARCHAR (510) NULL,
    [is_national] BIT           NULL,
    [venue_id]    INT           NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO
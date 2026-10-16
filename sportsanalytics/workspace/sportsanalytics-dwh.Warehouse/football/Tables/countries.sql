CREATE TABLE [football].[countries] (
    [id]            INT           NOT NULL,
    [code]          VARCHAR (10)  NOT NULL,
    [name]          VARCHAR (100) NOT NULL,
    [flag]          VARCHAR (255) NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO
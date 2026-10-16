CREATE TABLE [football].[venues] (
    [id]            INT           NOT NULL,
    [name]          VARCHAR (255) NOT NULL,
    [city]          VARCHAR (255) NULL,
    [capacity]      INT           NULL,
    [surface]       VARCHAR (255) NULL,
    [address]       VARCHAR (510) NULL,
    [image]         VARCHAR (510) NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO
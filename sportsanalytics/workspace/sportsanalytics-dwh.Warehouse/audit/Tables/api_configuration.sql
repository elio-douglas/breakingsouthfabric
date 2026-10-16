CREATE TABLE [audit].[api_configuration] (
    [id]            BIGINT        IDENTITY NOT NULL,
    [report]        VARCHAR (255) NOT NULL,
    [url]           VARCHAR (255) NOT NULL,
    [endpoint]      VARCHAR (255) NOT NULL,
    [headers]       VARCHAR (MAX) NULL,
    [params]        VARCHAR (MAX) NULL,
    [frequency]     VARCHAR (50)  NOT NULL,
    [interval]      VARCHAR (50)  NOT NULL,
    [active]        VARCHAR (50)  NOT NULL,
    [stage]         VARCHAR (50)  NOT NULL,
    [dw_updated_at] VARCHAR (50)  NOT NULL
);


GO
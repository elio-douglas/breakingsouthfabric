CREATE TABLE [audit].[table_loads] (
    [batch_id]      BIGINT          IDENTITY NOT NULL,
    [schema_name]   VARCHAR (128)   NOT NULL,
    [table_name]    VARCHAR (128)   NOT NULL,
    [loaded_at]     DATETIME2 (6)   NOT NULL,
    [rows_inserted] BIGINT          NULL,
    [rows_updated]  BIGINT          NULL,
    [rows_deleted]  BIGINT          NULL,
    [dw_updated_at] DATETIME2 (6) NULL
);


GO

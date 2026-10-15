CREATE TABLE [football].[event_types]
(
  [id] INT NOT NULL PRIMARY KEY,
  [type] NVARCHAR(255) NOT NULL,
  [detail] NVARCHAR(255) NOT NULL,
  [comments] NVARCHAR(255) NULL,
  [valid_from] DATE NOT NULL DEFAULT '1900-01-01',
  [valid_to] DATE NOT NULL DEFAULT '9999-12-31',
  [is_current] BIT NOT NULL DEFAULT 1
)

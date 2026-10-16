# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "758791c1-c232-45f0-b048-3cfa22ea209d",
# META       "default_lakehouse_name": "sportsanalytics",
# META       "default_lakehouse_workspace_id": "12cea0cf-1516-4301-813d-e2629002d503",
# META       "known_lakehouses": [
# META         {
# META           "id": "758791c1-c232-45f0-b048-3cfa22ea209d"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # Sports Analytics - Football - Microsoft Fabric

# MARKDOWN ********************

# ## Configuration

# MARKDOWN ********************

# ### Packages

# CELL ********************

!pip install duckdb

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import duckdb
import json
from datetime import datetime, timezone
from pyspark.sql import types as T

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Variables

# CELL ********************

vault = "https://breakingsouthkv.vault.azure.net/"
project = "sportsanalytics"
scope = "football"
lakehouse_id = notebookutils.lakehouse.get(project).id
workspace_id = notebookutils.runtime.context["currentWorkspaceId"]
abfss_root = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Files"
tables_root = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Tables"
config_path = f"{abfss_root}/{project}/{scope}/api-config.csv"
raw_root = f"{abfss_root}/{project}-onelake/{scope}/raw"
api_key = notebookutils.credentials.getSecret(vault, "apisports-key")
token = notebookutils.credentials.getToken("storage")
con = duckdb.connect()
if not con.sql(f"""
    CREATE OR REPLACE SECRET onelake (
        TYPE azure,
        PROVIDER access_token,
        ACCESS_TOKEN '{token}',
        ACCOUNT_NAME 'onelake'
    )
"""):
    print("Secret onelake not created.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Parameters

# CELL ********************

countries = ["england", "italy", "spain", "germany", "france"]

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Classes

# CELL ********************

class Entity:
    def __init__(self, table_row: tuple):
        self.report = table_row[0]
        self.url = table_row[1]
        self.endpoint = table_row[2]
        self.headers = table_row[3]
        self.params = table_row[4]
        self.frequency = table_row[5]
        self.interval = table_row[6]
        self.is_active = table_row[7]
        self.stage = table_row[8]

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Functions

# MARKDOWN ********************

# #### `collect_entities`

# CELL ********************

def collect_entities(stage: int):
    entities = con.sql(f"""
        SELECT
            raw.*
        FROM
            read_csv_auto('{config_path}') AS raw
        WHERE
            raw.stage = {stage}
    """).fetchall()
    # Convert the raw tuples into Entity objects
    return [Entity(row) for row in entities]

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### `download_data`

# CELL ********************

def download_data(entity: Entity):
  # Configure request details
  headers = {"x-apisports-key": api_key}
  params = "?" + entity.params if entity.params is not None else ""
  # Perform the request to download the data
  raw_data = requests.get(f"{entity.url}/{entity.endpoint}{params}", headers=headers)
  return raw_data.json()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### `upload_raw`

# CELL ********************

def upload_raw(response, name):
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    path = f"{raw_root}/{name}/{ts}.json"
    notebookutils.fs.put(path, json.dumps(response), overwrite=False)
    print(f"Uploaded raw data for entity: {name} at {ts}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### `create_raw_table`

# CELL ********************

def latest_json(folder: str):
    files = [f for f in notebookutils.fs.ls(folder) if f.name.endswith(".json")]
    return max(files, key=lambda f: f.name).path if files else None


def create_raw_table(entity: str, table_name: str, nested: bool = False):
    entity_root = f"{raw_root}/{entity}"
    if not nested:
        data_path = [latest_json(entity_root)]
    else:
        # Latest file of each parameter subfolder (e.g. raw/teams/<league>/<ts>.json)
        data_path = [latest_json(d.path) for d in notebookutils.fs.ls(entity_root) if d.isDir]
    data_path = [p for p in data_path if p]
    if not data_path:
        raise FileNotFoundError(f"No raw JSON files found under {entity_root}")

    paths_sql = "[" + ", ".join(f"'{p}'" for p in data_path) + "]"
    con.sql(f"CREATE OR REPLACE TABLE {table_name} AS SELECT * FROM read_json_auto({paths_sql})")
    print(f"Created raw table in duckdb memory: {table_name}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### `save_table`

# CELL ********************

SPARK_TYPES = {
    "BOOLEAN": T.BooleanType(),
    "TINYINT": T.ByteType(),
    "SMALLINT": T.ShortType(),
    "INTEGER": T.IntegerType(),
    "BIGINT": T.LongType(),
    "FLOAT": T.FloatType(),
    "DOUBLE": T.DoubleType(),
    "DATE": T.DateType(),
    "TIMESTAMP": T.TimestampType(),
    "VARCHAR": T.StringType(),
}


def save_table(table_name: str, query: str):
    # Keep the result in duckdb memory so later queries can join to it, then persist it as Delta
    con.sql(f"CREATE OR REPLACE TABLE {table_name} AS {query}")
    rel = con.table(table_name)
    columns, fields = [], []
    for name, dtype in zip(rel.columns, rel.types):
        spark_type = SPARK_TYPES.get(str(dtype))
        # Unmapped duckdb types (JSON, HUGEINT, ...) are persisted as strings
        columns.append(f'"{name}"' if spark_type else f'CAST("{name}" AS VARCHAR) AS "{name}"')
        fields.append(T.StructField(name, spark_type or T.StringType(), True))
    # Explicit schema avoids pandas turning nullable integer columns into doubles
    rows = con.sql(f"SELECT {', '.join(columns)} FROM {table_name}").fetchall()
    df = spark.createDataFrame(rows, T.StructType(fields))
    df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable(f"{scope}.{table_name}")
    print(f"Saved Delta table: {scope}.{table_name} ({len(rows)} rows)")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Execution

# MARKDOWN ********************

# ### Stage 1

# MARKDOWN ********************

# #### Data Extraction

# CELL ********************

entities = collect_entities(stage=1)

for entity in entities:
    has_param = entity.params is not None
    # Check if the entity is active before processing
    if entity.is_active:
        raw_data = download_data(entity)
        nested_path = entity.params.partition("=")[2] if has_param else None
        entity_name = f"{entity.report}/{nested_path}" if has_param else entity.report
        upload_raw(raw_data["response"], entity_name)
    # Create raw table for the entity
    create_raw_table(entity.report, f"latest_{entity.report}", nested=has_param)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### Data Modeling

# MARKDOWN ********************

# ##### Countries

# CELL ********************

save_table("raw_countries", """

  SELECT
    ROW_NUMBER() OVER (ORDER BY raw.name) AS id,
    CASE
      WHEN raw.name = 'World' THEN 'WD'
      ELSE raw.code
    END AS code,
    raw.name AS name,
    raw.flag AS flag
  FROM
    latest_countries AS raw

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ##### Leagues

# CELL ********************

save_table("raw_leagues", """

  SELECT
    ROW_NUMBER() OVER () AS id,
    raw.league.id AS code,
    raw.league.name AS name,
    raw.league.type AS type,
    raw.league.logo AS logo,
    c.id AS country_id
  FROM
    latest_leagues AS raw
    INNER JOIN raw_countries AS c ON raw.country.code = c.code

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ##### Seasons

# CELL ********************

save_table("raw_seasons", """

  WITH unnest_seasons AS (
    SELECT
      raw.league.id AS league_id,
      unnest(json_extract(raw.seasons, '$')::json[]) AS season
    FROM
      latest_leagues AS raw
  )

  SELECT
    ROW_NUMBER() OVER () AS id,
    l.id AS league_id,
    CAST(unn.season.start AS DATE) AS "start",
    CAST(unn.season.end AS DATE) AS "end",
    CAST(unn.season.current AS BOOLEAN) AS is_current
  FROM
    raw_leagues AS l
    INNER JOIN unnest_seasons AS unn ON l.code = unn.league_id

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Stage 2

# MARKDOWN ********************

# #### Data Extraction

# CELL ********************

entities = collect_entities(stage=2)

for entity in entities:
    has_param = entity.params is not None
    # Check if the entity is active before processing
    if entity.is_active:
        raw_data = download_data(entity)
        nested_path = entity.params.partition("=")[2] if has_param else None
        entity_name = f"{entity.report}/{nested_path}" if has_param else entity.report
        upload_raw(raw_data["response"], entity_name)
    # Create raw table for the entity
    create_raw_table(entity.report, f"latest_{entity.report}", nested=has_param)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### Data Modeling

# MARKDOWN ********************

# ##### Venues

# CELL ********************

save_table("raw_venues", """

  SELECT DISTINCT
    raw.venue.id AS id,
    raw.venue.name AS name,
    raw.venue.city AS city,
    raw.venue.capacity AS capacity,
    raw.venue.surface AS surface,
    raw.venue.address AS address,
    raw.venue.image AS image
  FROM
    latest_teams AS raw
  WHERE
    raw.venue.id IS NOT NULL
  QUALIFY
    ROW_NUMBER() OVER (PARTITION BY raw.venue.id ORDER BY raw.venue.id) = 1

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ##### Teams

# CELL ********************

save_table("raw_teams", """

  SELECT
    raw.team.id AS id,
    raw.team.code AS code,
    raw.team.name AS name,
    raw.team.logo AS logo,
    raw.team.national AS is_national,
    raw.venue.id AS venue_id
  FROM
    latest_teams AS raw
  QUALIFY
    ROW_NUMBER() OVER (PARTITION BY raw.team.id ORDER BY raw.team.id) = 1

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ##### Fixtures

# CELL ********************

save_table("raw_fixtures", """

  SELECT
    lm.fixture.id AS id,
    CAST(strftime(CAST(lm.fixture.date AS TIMESTAMP), '%Y%m%d') AS INT) AS date_id,
    CAST(strftime(CAST(lm.fixture.date AS TIMESTAMP), '%H%M') AS INT) AS time_id,
    CAST(lm.league.id AS SMALLINT) AS league_id,
    CAST(lm.teams.home.id AS SMALLINT) AS home_team_id,
    CAST(lm.teams.away.id AS SMALLINT) AS away_team_id,
    CAST(lm.score.halftime.home AS SMALLINT) AS halftime_home,
    CAST(lm.score.halftime.away AS SMALLINT) AS halftime_away,
    CAST(lm.score.fulltime.home AS SMALLINT) AS fulltime_home,
    CAST(lm.score.fulltime.away AS SMALLINT) AS fulltime_away,
    CAST(lm.score.extratime.home AS SMALLINT) AS extratime_home,
    CAST(lm.score.extratime.away AS SMALLINT) AS extratime_away,
    CAST(lm.score.penalty.home AS SMALLINT) AS penalty_home,
    CAST(lm.score.penalty.away AS SMALLINT) AS penalty_away
  FROM
    latest_matches lm

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ##### Event Types

# CELL ********************

save_table("raw_event_types", """

  SELECT DISTINCT
    CAST(ROW_NUMBER() OVER () AS SMALLINT) AS id,
    LOWER(le.type) AS type,
    LOWER(le.detail) AS detail,
    LOWER(le.comments) AS comments
  FROM
    latest_events le

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ##### Events

# CELL ********************

save_table("raw_events", """

  SELECT
    1223598 AS fixture_id,
    le.time.elapsed AS minute_id,
    le.team.id AS team_id,
    le.player.id AS player_id,
    le.assist.id AS player_out_id,
    et.id AS event_type_id
  FROM
    latest_events le
    LEFT JOIN raw_event_types et
      ON LOWER(le.type) = et.type
      AND COALESCE(LOWER(le.detail), '') = COALESCE(et.detail, '')
      AND COALESCE(LOWER(le.comments), '') = COALESCE(et.comments, '')

""")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

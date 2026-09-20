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

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

vault = "https://breakingsouthkv.vault.azure.net/"
project = "sportsanalytics"
scope = "football"
lakehouse_id = notebookutils.lakehouse.get(project).id
workspace_id = notebookutils.runtime.context["currentWorkspaceId"]
abfss_root = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Files"
tables_root = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Tables"
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

# CELL ********************

def collect_entities(stage: int):
    entities = con.sql(f"""
        SELECT
            raw.*
        FROM
            read_csv_auto('{abfss_root}/{project}/{scope}/api-config.csv') AS raw
        WHERE
            raw.stage = 1
    """).fetchall()
    # Convert the raw tuples into Entity objects
    return [Entity(row) for row in entities]

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

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

# CELL ********************

def upload_raw(response, name):
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    path = f"{abfss_root}/{project}-onelake/{scope}/raw/{name}/{ts}.json"
    notebookutils.fs.put(path, json.dumps(response), overwrite=False)
    print(f"Uploaded raw data for entity: {name} at {ts}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def create_raw_table(entity: str, table_name: str, nested: bool = False):
    files = notebookutils.fs.ls(f"{abfss_root}/{project}-onelake/{scope}/raw/{entity}")
    latest = max((f for f in files if f.name.endswith(".json")), key=lambda f: f.name)
    con.sql(f"""
        CREATE TABLE {entity} AS
        SELECT
            *
        FROM
            read_json_auto('{latest.path}')
    """)
    print(f"Created table in duckdb memory: {scope}.{table_name}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

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
    create_raw_table(entity.report, f"raw_{entity.report}", nested=has_param)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df = spark.createDataFrame(con.sql(f"""
  SELECT
    ROW_NUMBER() OVER (ORDER BY raw.name) AS id,
    CASE
      WHEN raw.name = 'World' THEN 'WD'
      ELSE raw.code
    END AS code,
    raw.name AS name,
    raw.flag AS flag
  FROM
    countries raw
""").df())
df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable("football.raw_countries")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df = spark.createDataFrame(con.sql(f"""

  WITH unnest_seasons AS (
    SELECT
      raw.league.id AS league_id,
      unnest(json_extract(raw.seasons, '$')::json[]) AS season
    FROM
      leagues AS raw
  )

  SELECT
    raw.league.id AS league_id,
    CAST(unn.season.start AS DATE) AS season_start,
    CAST(unn.season.end AS DATE) AS season_end,
    CAST(unn.season.current AS BOOLEAN) AS is_current
  FROM
    leagues AS raw
    INNER JOIN unnest_seasons AS unn ON raw.league.id = unn.league_id
    
""").df())
df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable("football.raw_seasons")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df = spark.createDataFrame(con.sql(f"""

  SELECT
    raw.league.id AS id,
    raw.league.name AS name,
    raw.league.type AS type,
    raw.league.logo AS logo,
    raw.country.code AS country_code
  FROM
    leagues AS raw
    
""").df())
df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable("football.raw_leagues")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

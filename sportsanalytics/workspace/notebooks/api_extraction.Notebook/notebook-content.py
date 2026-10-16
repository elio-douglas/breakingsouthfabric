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

# # API Extraction - Microsoft Fabric

# MARKDOWN ********************

# ## Configuration

# MARKDOWN ********************

# ### Parameters

# CELL ********************

try: project
except NameError: project = "sportsanalytics"

try: scope
except NameError: scope = "football"

try: report
except NameError: report = "leagues"

try: url
except NameError: url = "https://v3.football.api-sports.io"

try: endpoint
except NameError: endpoint = "leagues"

try: headers
except NameError: headers = None

try: params
except NameError: params = None

try: frequency
except NameError: frequency = "year"

try: interval
except NameError: interval = "1"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Packages

# CELL ********************

import requests
import json
import os
from datetime import datetime, timezone

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Variables

# CELL ********************

vault = "https://breakingsouthkv.vault.azure.net/"
lakehouse_id = notebookutils.lakehouse.get(project).id
workspace_id = notebookutils.runtime.context["currentWorkspaceId"]
abfss_root = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Files"
tables_root = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Tables"
raw_root = f"{abfss_root}/{project}/{scope}/raw"
api_key = notebookutils.credentials.getSecret(vault, "apisports-key")

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

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ### Functions

# MARKDOWN ********************

# #### `download_data`

# CELL ********************

def download_data(entity: Entity):
    # Configure request details
    headers = {"x-apisports-key": api_key}
    url = entity.url
    endpoint = entity.endpoint
    params = "?" + entity.params if entity.params is not None else ""
    # Perform the request to download the data
    raw_data = requests.get(f"{url}/{endpoint}{params}", headers=headers)
    return raw_data.json()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### `upload_raw`

# CELL ********************

# def upload_raw(response, name):
#     ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
#     container.upload_blob(f"{main_folder}/{name}/{ts}.json", json.dumps(response), overwrite=False)
#     print(f"Uploaded raw data for entity: {name} at {ts}")

def upload_raw(response, name):
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    path = f"/lakehouse/default/Files/{project}/{scope}/{name}/{ts}.json"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(response, f)
    print(f"Uploaded raw data for entity: {name} at {ts}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# #### `create_raw_table`

# CELL ********************

def create_raw_table(entity: str, table_name: str, nested: bool = False):
    return 1

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Execution

# CELL ********************

row = (report, url, endpoint, headers, params, frequency, interval)
entity = Entity(row)

has_param = entity.params is not None
raw_data = download_data(entity)
nested_path = entity.params.partition("=")[2] if has_param else None
entity_name = f"{entity.report}/{nested_path}" if has_param else entity.report
upload_raw(raw_data["response"], entity_name)
# Create raw table for the entity
# create_raw_table(entity.report, f"latest_{entity.report}", nested=has_param)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

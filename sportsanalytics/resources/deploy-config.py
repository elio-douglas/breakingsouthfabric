# Import necessary libraries
from pathlib import Path
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# Set credentials
credential = DefaultAzureCredential()

# Define secret loading function
client = SecretClient(vault_url="https://breakingsouthkv.vault.azure.net/", credential=credential)
secret = client.get_secret("breakingsouthsa-connection-string")

# Environment settings
container_name = "sportsanalytics"
main_folder = "football"
AZURE_STORAGE_CONNECTION_STRING = secret.value
blob_service = BlobServiceClient.from_connection_string(AZURE_STORAGE_CONNECTION_STRING)
container = blob_service.get_container_client(container_name)

# Stream csv data
with open(Path(__file__).parent / "api-config.csv", "r") as f:
    csv_data = f.read()

# Upload csv data to Azure Blob Storage for football configuration
container.upload_blob(f"{main_folder}/api-config.csv", csv_data, overwrite=True)
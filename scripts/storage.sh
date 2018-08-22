# storage, called from deploy.sh with env vars set
echo creating storage account, container, diagsettings
base_name=${AZURE_BASE_NAME}
storage_group_name=${base_name}-storage
storage_account_name="$(echo ${base_name} | sed 's/[- _]//g')stor"
storage_container_name=origin
storage_diagsettings_name=storage-diagsettings

storage_account_id=$(az storage account create \
    --name $storage_account_name \
    --resource-group $storage_group_name \
    --location $location \
    --default-action Allow \
    --output tsv --query id)
echo created: $storage_account_id

az storage container create \
    --name $storage_container_name \
    --account-name $storage_account_name \
    --output tsv --query id

storage_logs_json=$(cat "${__root}/specs/storage.logs")
storage_metrics_json=$(cat "${__root}/specs/storage.metrics")

resource_uri=$storage_account_id
settings_name=$storage_diagsettings_name
logs_json=$storage_logs_json
metrics_json=$storage_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $monitor_hub_name \
    --event-hub-rule $monitor_policy_id \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv

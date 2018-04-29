# storage, called from deploy.sh with env vars set
echo creating storage account, container, diagsettings
storage_group_name=$DEFAULT_GROUP_NAME
storage_account_name=$STORAGE_ACCOUNT_NAME
storage_container_name=root
storage_diagsettings_name=storage-diag-settings

storage_account_id=$(az storage account create \
    --name $storage_account_name \
    --resource-group $storage_group_name \
    --location $DEFAULT_LOCATION \
    --default-action Allow \
    --output tsv --query id \
)
echo created: $storage_account_id

az storage container create \
    --name $storage_container_name \
    --account-name $storage_account_name \
    --output tsv --query id

storage_logs_json=$(cat "$ROOT_DIR/specs/storage.logs")
storage_metrics_json=$(cat "$ROOT_DIR/specs/storage.metrics")

resource_uri=$storage_account_id
settings_name=$storage_diagsettings_name
logs_json=$storage_logs_json
metrics_json=$storage_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $MONITOR_HUB_NAME \
    --event-hub-rule $MONITOR_SASPOLICY_ID \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv

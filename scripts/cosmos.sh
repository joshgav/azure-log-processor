# cosmos
echo creating cosmos account, db, collection, diagsettings
base_name=${AZURE_BASE_NAME}
cosmos_group_name=${base_name}-group
cosmos_account_name=${base_name}-cosmosdb
cosmos_db_name=${base_name}-db
cosmos_collection_name=${base_name}-coll
cosmos_account_kind=GlobalDocumentDB
cosmos_account_consistency=BoundedStaleness
cosmos_account_consistency_maxinterval=10
cosmos_diagsettings_name=cosmos-diagsettings

## account
cosmos_account_id=$(az cosmosdb show \
    --name $cosmos_account_name \
    --resource-group $cosmos_group_name \
    --query id --output tsv 2> /dev/null)
if [ -z "$cosmos_account_id" ]; then
    cosmos_account_id=$(az cosmosdb create \
        --name $cosmos_account_name \
        --resource-group $cosmos_group_name \
        --kind $cosmos_account_kind \
        --default-consistency-level $cosmos_account_consistency \
        --max-interval $cosmos_account_consistency_maxinterval \
        --query id --output tsv)
fi
echo found: $cosmos_account_id

cosmos_account_key=$(az cosmosdb list-keys \
        --name $cosmos_account_name \
        --resource-group $cosmos_group_name \
        --query primaryMasterKey --output tsv)

## database
cosmos_db_exists=$(az cosmosdb database exists \
    --db-name $cosmos_db_name \
    --name $cosmos_account_name \
    --resource-group-name $cosmos_group_name \
    --key $cosmos_account_key \
    --output tsv 2> /dev/null)
if [ "x$cosmos_db_exists" == "xfalse" ]; then
    cosmos_db_id=$(az cosmosdb database create \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query id --output tsv)
else
    cosmos_db_id=$(az cosmosdb database show \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query id --output tsv 2> /dev/null)
fi
echo found: $cosmos_db_id

## collection
cosmos_collection_exists=$(az cosmosdb collection exists \
    --collection-name $cosmos_collection_name \
    --db-name $cosmos_db_name \
    --name $cosmos_account_name \
    --resource-group-name $cosmos_group_name \
    --key $cosmos_account_key \
    --output tsv 2> /dev/null)
if [ "x$cosmos_collection_exists" == "xfalse" ]; then
    cosmos_collection_id=$(az cosmosdb collection create \
        --collection-name $cosmos_collection_name \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query 'collection.id' --output tsv)
else
    cosmos_collection_id=$(az cosmosdb collection show \
        --collection-name $cosmos_collection_name \
        --db-name $cosmos_db_name \
        --name $cosmos_account_name \
        --resource-group-name $cosmos_group_name \
        --key $cosmos_account_key \
        --query 'collection.id' --output tsv 2> /dev/null)
fi
echo found: $cosmos_collection_id
    
## diagsettings
cosmos_logs_json=$(cat "${__root}/specs/cosmosdb.logs")
cosmos_metrics_json=$(cat "${__root}/specs/cosmosdb.metrics")

resource_uri=$cosmos_account_id
settings_name=$cosmos_diagsettings_name
logs_json=$cosmos_logs_json
metrics_json=$cosmos_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $monitor_hub_name \
    --event-hub-rule $monitor_policy_id \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv


# sql
echo creating sql server, db, firewall rules, diagsettings
base_name=${AZURE_BASE_NAME}
sql_group_name=${base_name}-group
sql_server_name=${base_name}-server
sql_db_name=${base_name}-db
sql_location=${AZURE_DEFAULT_LOCATION}
sql_user=$SQL_USER
sql_password=$SQL_PASSWORD
sql_diagsettings_name=sql-diag-settings

sql_server_id=$(az sql server show \
    --name $sql_server_name \
    --resource-group $sql_group_name \
    --output tsv --query id 2> /dev/null)
if [ -z "$sql_server_id" ]; then
    sql_server_id=$(az sql server create \
        --name $sql_server_name \
        --resource-group $sql_group_name \
        --location $sql_location \
        --admin-user $sql_user \
        --admin-password $sql_password \
        --output tsv --query id)
fi
echo found: $sql_server_id


rule01_id=$(az sql server firewall-rule create \
    --name 'unsafe-allow-all' \
    --server $sql_server_name \
    --resource-group $sql_group_name \
    --start-ip-address '0.0.0.0' \
    --end-ip-address '255.255.255.255' \
    --query id --output tsv)
echo created: $rule01_id

rule02_id=$(az sql server firewall-rule create \
    --name 'allow-azure' \
    --server $sql_server_name \
    --resource-group $sql_group_name \
    --start-ip-address '0.0.0.0' \
    --end-ip-address '0.0.0.0' \
    --query id --output tsv)
echo created: $rule02_id

sql_db_id=$(az sql db show \
    --name $sql_db_name \
    --resource-group $sql_group_name \
    --server $sql_server_name \
    --query id --output tsv 2> /dev/null) 
if [ -z "$sql_db_id" ]; then
    sql_db_id=$(az sql db create \
        --name $sql_db_name \
        --resource-group $sql_group_name \
        --server $sql_server_name \
        --query id --output tsv)
fi
echo found: $sql_db_id

sql_logs_json=$(cat "${__root}/specs/sqldb.logs")
sql_metrics_json=$(cat "${__root}/specs/sqldb.metrics")

resource_uri=$sql_db_id
settings_name=$sql_diagsettings_name
logs_json=$sql_logs_json
metrics_json=$sql_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $monitor_hub_name \
    --event-hub-rule $monitor_policy_id \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv


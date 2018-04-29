# sql
echo creating sql server, db, firewall rules, diagsettings
sql_group_name=$DEFAULT_GROUP_NAME
sql_server_name=$SQL_SERVER_NAME
sql_db_name=$SQL_DB_NAME
sql_location=$DEFAULT_LOCATION
sql_user_name=$SQL_USER_NAME
sql_pw=$SQL_PASSWORD
sql_diagsettings_name=sql-diag-settings

sql_server_id=$(az sql server show \
    --name $sql_server_name \
    --resource-group $sql_group_name \
    --output tsv --query id \
)

if [ -z "$sql_server_id" ]; then
    sql_server_id=$(az sql server create \
        --name $sql_server_name \
        --resource-group $sql_group_name \
        --location $sql_location \
        --admin-user $sql_user_name \
        --admin-password $sql_pw \
        --output tsv --query id \
    )
    echo created: $sql_server_id
else
    echo found: $sql_server_id
fi


rule01_id=$(az sql server firewall-rule create \
    --name 'unsafe-allow-all' \
    --server $sql_server_name \
    --resource-group $sql_group_name \
    --start-ip-address '0.0.0.0' \
    --end-ip-address '255.255.255.255' \
    --query id --output tsv \
)
echo created: $rule01_id

rule02_id=$(az sql server firewall-rule create \
    --name 'allow-azure' \
    --server $sql_server_name \
    --resource-group $sql_group_name \
    --start-ip-address '0.0.0.0' \
    --end-ip-address '0.0.0.0' \
    --query id --output tsv \
)
echo created: $rule02_id

sql_db_id=$(az sql db show \
    --name $sql_db_name \
    --resource-group $sql_group_name \
    --server $sql_server_name \
    --query id --output tsv \
    )

if [ -z "$sql_db_id" ]; then
    sql_db_id=$(az sql db create \
        --name $sql_db_name \
        --resource-group $sql_group_name \
        --server $sql_server_name \
        --query id --output tsv \
        )
    echo created: $sql_db_id
else
    echo found: $sql_db_id
fi

sql_logs_json=$(cat "$ROOT_DIR/specs/sqldb.logs")
sql_metrics_json=$(cat "$ROOT_DIR/specs/sqldb.metrics")

resource_uri=$sql_db_id
settings_name=$sql_diagsettings_name
logs_json=$sql_logs_json
metrics_json=$sql_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $MONITOR_HUB_NAME \
    --event-hub-rule $MONITOR_SASPOLICY_ID \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv


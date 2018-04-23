#! /bin/bash

set -o allexport
source .env
set +o allexport

# globals
location=westus2
group_name=$EH_GROUP_NAME
cleanup=0

# event hubs
eh_group_name=$group_name
namespace_name=$EH_NAMESPACE_NAME
eventhub_name=$EH_HUB_NAME
eventhub_authzrule_name=${eventhub_name}-authzrule
eventhub_diag_settings_name=eh_arm_diag

group_exists=$(az group exists -n $eh_group_name -o tsv)

if [ "x${group_exists}" == "xfalse" ]; then
    group_id=$(az group create \
        --location $location \
        --name $eh_group_name \
        --output tsv --query id \
    )
    echo created: $group_id
fi


eh_namespace_id=$(az eventhubs namespace create \
    --name $namespace_name \
    --resource-group $eh_group_name \
    --location $location \
    --query id --output tsv \
)
echo created: $eh_namespace_id

eh_hub_id=$(az eventhubs eventhub create \
    --resource-group $eh_group_name \
    --name $eventhub_name \
    --namespace-name $namespace_name \
    --query id --output tsv \
    #TODO(joshgav) --enable-capture true
)
echo created: $eh_hub_id

eh_authzrule_id=$(az eventhubs eventhub authorization-rule create \
    --name $eventhub_authzrule_name \
    --eventhub-name $eventhub_name \
    --namespace-name $namespace_name \
    --resource-group $eh_group_name \
    --rights 'Send' \
    --query id --output tsv \
)
echo created: $eh_authzrule_id

az monitor diagnostic-settings create \
    --name ${eventhub_diag_settings_name} \
    --event-hub $eventhub_name \
    --event-hub-rule $eh_authzrule_id \
    --resource $eh_namespace_id
# TODO(joshgav): does --logs and all categories need to be specified?


# storage
storage_group_name=$group_name
storage_account_name=$STORAGE_ACCOUNT_NAME
storage_container_name=root
storage_diag_settings_name=storage_arm_diag

storage_account_id=$(az storage account create \
    --name $storage_account_name \
    --resource-group $storage_group_name \
    --location $location \
    --default-action Allow \
    --output tsv --query id \
)
echo created: $storage_account_id

az storage container create \
    --name $storage_container_name \
    --account-name $storage_account_name \
    --output tsv --query id

az monitor diagnostic-settings create \
    --name ${storage_diag_settings_name} \
    --event-hub $eventhub_name \
    --event-hub-rule $eh_authzrule_id \
    --resource $storage_account_id

# sql
sql_server_name=$SQL_SERVER_NAME
sql_db_name=$SQL_DB_NAME
sql_group_name=$group_name
sql_location=westus2
sql_diag_settings_name=sql_arm_diag
sql_user_name=demosqluser
sql_pw=NoSoupForYou1

sql_server_id=$(az sql server create \
    --name $sql_server_name \
    --resource-group $sql_group_name \
    --location $sql_location \
    --admin-user $sql_user_name \
    --admin-password $sql_pw \
    --output tsv --query id \
)
echo created: $sql_server_id

az sql server firewall-rule create \
    --name 'unsafe-allow-all' \
    --server $sql_server_name \
    --resource-group $sql_group_name \
    --start-ip-address '0.0.0.0' \
    --end-ip-address '255.255.255.255'

az sql server firewall-rule create \
    --name 'allow-azure' \
    --server $sql_server_name \
    --resource-group $sql_group_name \
    --start-ip-address '0.0.0.0'

sql_db_id=$(az sql db create \
    --name $sql_db_name \
    --resource-group $sql_group_name \
    --server $sql_server_name \
    --query id --output tsv \
)

az monitor diagnostic-settings create \
    --name ${sql_diag_settings_name} \
    --event-hub $eventhub_name \
    --event-hub-rule $eh_authzrule_id \
    --resource $sql_server_id

# cleanup
if [ "x$cleanup" == "x1" ]; then
    echo deleting group $eh_group_name
    az group delete --no-wait --yes --name $group_name
fi

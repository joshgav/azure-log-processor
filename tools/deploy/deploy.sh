#! /bin/bash

# globals
export DEPLOY_TOOLS_DIR=$(dirname "${BASH_SOURCE[0]}")
export ROOT_DIR="$(cd "${DEPLOY_TOOLS_DIR}/../.." && pwd)"

export DEFAULT_LOCATION=westus2
export DEFAULT_GROUP_NAME=$EVENTHUB_GROUP_NAME
export CLEANUP=0

echo "importing env vars from .env (loaded last)"
set -o allexport
source .env
set +o allexport

# event hubs
echo creating Event Hubs namespace, sas_policy, hub, diag_settings
eh_group_name=$EVENTHUB_GROUP_NAME
eh_namespace_name=$EVENTHUB_NAMESPACE_NAME
eh_hub_name=$EVENTHUB_HUB_NAME
eh_saspolicy_name=$EVENTHUB_SAS_POLICY_NAME
eh_diagsettings_name=eventhubs-diagsettings

eh_group_id=$(az group show -n $eh_group_name --query id -o tsv)

if [ -z "$eh_group_id" ]; then
    eh_group_id=$(az group create \
        --location $DEFAULT_LOCATION \
        --name $eh_group_name \
        --output tsv --query id \
    )
    echo created: $eh_group_id
else
    echo found: $eh_group_id
fi

eh_namespace_id=$(az eventhubs namespace show \
    --name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query id --output tsv \
)

if [ -z "$eh_namespace_id" ]; then
    eh_namespace_id=$(az eventhubs namespace create \
        --name $eh_namespace_name \
        --resource-group $eh_group_name \
        --location $DEFAULT_LOCATION \
        --query id --output tsv \
    )
    echo created: $eh_namespace_id
else
    echo found: $eh_namespace_id
fi

eh_authzrule_id=$(az eventhubs namespace authorization-rule show \
    --name $eh_saspolicy_name \
    --namespace-name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query id --output tsv \
    )

if [ -z "$eh_authzrule_id" ]; then
    eh_authzrule_id=$(az eventhubs namespace authorization-rule create \
        --name $eh_saspolicy_name \
        --namespace-name $eh_namespace_name \
        --resource-group $eh_group_name \
        --rights Manage Send Listen \
        --query id --output tsv \
    )
    echo created: $eh_authzrule_id
else
    echo found: $eh_authzrule_id
fi

eh_saskey_value=$(az eventhubs namespace authorization-rule keys list \
    --name $eh_saspolicy_name \
    --namespace-name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query primaryKey --output tsv \
)
echo found sas key value: $eh_saskey_value

eh_hub_id=$(az eventhubs eventhub show \
    --name $eh_hub_name \
    --namespace-name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query id --output tsv \
    )

if [ -z "$eh_hub_id" ]; then
    eh_hub_id=$(az eventhubs eventhub create \
        --name $eh_hub_name \
        --namespace-name $eh_namespace_name \
        --resource-group $eh_group_name \
        --query id --output tsv \
    )
    echo created: $eh_hub_id
else
    echo found: $eh_hub_id
fi

eh_logs_json=$(cat "$ROOT_DIR/specs/eventhubs.logs")
eh_metrics_json=$(cat "$ROOT_DIR/specs/eventhubs.metrics")

resource_uri=$eh_namespace_id
settings_name=$eh_diagsettings_name
logs_json=$eh_logs_json
metrics_json=$eh_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $eh_hub_name \
    --event-hub-rule $eh_authzrule_id \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv

# for use in other diag settings rules
export MONITOR_HUB_NAME=$eh_hub_name
export MONITOR_SASPOLICY_ID=$eh_authzrule_id

# sql
DEFAULT_LOCATION=westus2 $DEPLOY_TOOLS_DIR/sql.sh

# cosmosdb
DEFAULT_LOCATION=westus2 $DEPLOY_TOOLS_DIR/cosmos.sh


# cleanup
if [ "x$CLEANUP" == "x1" ]; then
    echo cleanup: deleting group $DEFAULT_GROUP_NAME
    az group delete --no-wait --yes --name $DEFAULT_GROUP_NAME
else
    echo no cleanup
fi

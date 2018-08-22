#!/usr/bin/env bash

set -o allexport
__dirname=$(dirname "${BASH_SOURCE[0]}")
__root="$(cd "${__dirname}/.." && pwd)"
if [[ -f ${__root}/.env ]]; then source ${__root}/.env; fi
base_name=${AZURE_BASE_NAME}
location=${AZURE_DEFAULT_LOCATION}
CLEANUP=0
set +o allexport

# event hubs
echo creating Event Hubs namespace, sas_policy, hub, diag_settings
eh_group_name=${base_name}-group
eh_namespace_name="$(echo ${base_name} | sed 's/[- _]//g')ns"
eh_hub_name=${base_name}-hub
eh_saspolicy_name=${base_name}-policy
eh_diagsettings_name=eventhubs-diagsettings

# ensure group
eh_group_id=$(az group show --name $eh_group_name --query id -o tsv 2> /dev/null)
if [ -z "$eh_group_id" ]; then
    eh_group_id=$(az group create \
        --location $location \
        --name $eh_group_name \
        --output tsv --query id)
fi
echo found: $eh_group_id

# ensure namespace
eh_namespace_id=$(az eventhubs namespace show \
    --name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query id --output tsv 2> /dev/null)
if [ -z "$eh_namespace_id" ]; then
    eh_namespace_id=$(az eventhubs namespace create \
        --name $eh_namespace_name \
        --resource-group $eh_group_name \
        --location $location \
        --query id --output tsv)
fi
echo found: $eh_namespace_id

# ensure SAS policy
eh_policy_id=$(az eventhubs namespace authorization-rule show \
    --name $eh_saspolicy_name \
    --namespace-name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query id --output tsv 2> /dev/null)
if [ -z "$eh_policy_id" ]; then
    eh_policy_id=$(az eventhubs namespace authorization-rule create \
        --name $eh_saspolicy_name \
        --namespace-name $eh_namespace_name \
        --resource-group $eh_group_name \
        --rights Manage Send Listen \
        --query id --output tsv)
fi
echo found: $eh_policy_id

# get SAS policy key
eh_policy_key=$(az eventhubs namespace authorization-rule keys list \
    --name $eh_saspolicy_name \
    --namespace-name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query primaryKey --output tsv)
echo found sas key value: $eh_policy_key

# ensure hub
eh_hub_id=$(az eventhubs eventhub show \
    --name $eh_hub_name \
    --namespace-name $eh_namespace_name \
    --resource-group $eh_group_name \
    --query id --output tsv 2> /dev/null)
if [ -z "$eh_hub_id" ]; then
    eh_hub_id=$(az eventhubs eventhub create \
        --name $eh_hub_name \
        --namespace-name $eh_namespace_name \
        --resource-group $eh_group_name \
        --query id --output tsv)
fi
echo found: $eh_hub_id

# used for resources in subscripts
export monitor_hub_name=$eh_hub_name
export monitor_policy_id=$eh_policy_id

# set up ARM activity log
all_az_locations=$(az account list-locations --output tsv --query '[].name' |
                    paste --serial --delimiters=" " -)
all_az_categories=$(echo Write Delete Action)

az monitor log-profiles create \
    --name 'default-log-profile' \
    --location $location \
    --locations $all_az_locations \
    --categories $all_az_categories \
    --service-bus-rule-id ${monitor_policy_id} \
    --days "7" \
    --enabled "true" \
    --output tsv --query id 

eh_logs_json=$(cat "${__root}/specs/eventhubs.logs")
eh_metrics_json=$(cat "${__root}/specs/eventhubs.metrics")

# set up monitoring for Event Hubs
resource_uri=$eh_namespace_id
settings_name=$eh_diagsettings_name
logs_json=$eh_logs_json
metrics_json=$eh_metrics_json
az monitor diagnostic-settings create \
    --resource $resource_uri \
    --name $settings_name \
    --event-hub $monitor_hub_name \
    --event-hub-rule $monitor_policy_id \
    --logs "$logs_json" \
    --metrics "$metrics_json" \
    --query id --output tsv


# deploy and monitor SQL
${__dirname}/sql.sh

# deploy and monitor CosmosDB
${__dirname}/cosmos.sh

# cleanup
if [ "x$CLEANUP" == "x1" ]; then
    echo cleanup: deleting group $eh_group_name
    az group delete --no-wait --yes --name $eh_group_name
else
    echo no cleanup
fi

#!/bin/bash

# Delete any existing service connections
function delete_service_connection {
    # Search for existing service connections
    echo "[+] Searching for existing service connection..."
    SERVICE_ENDPOINT_ID=$(az devops service-endpoint list --organization $AZDO_ORG_SERVICE_URL --project $TF_APP_NAME | jq -r '.[] | select( .type == "azurerm") | .id')

    if [ ! -z "$SERVICE_ENDPOINT_ID" ]
    then
        echo "[+] Deleting existing service connection: $SERVICE_ENDPOINT_ID"
        az devops service-endpoint delete --id $SERVICE_ENDPOINT_ID --organization $AZDO_ORG_SERVICE_URL --project $TF_APP_NAME --yes
    fi
}

# Create service connection
function create_service_connection {
    echo "[+] Fetching subscription name..."
    SUBSCRIPTION_NAME=$(az account list | jq -r ".[] | select(.id == \"$TF_SUBSCRIPTION_ID\") | .name") 

    echo "[+] Creating new service connection..."
    az devops service-endpoint azurerm create \
        --azure-rm-service-principal-id $TF_SP_ADO_ID \
        --azure-rm-subscription-id $TF_SUBSCRIPTION_ID \
        --azure-rm-tenant-id $TF_TENANT_ID \
        --name $TF_APP_NAME \
        --azure-rm-subscription-name $SUBSCRIPTION_NAME \
        --organization $AZDO_ORG_SERVICE_URL \
        --project $TF_APP_NAME
}

delete_service_connection
create_service_connection
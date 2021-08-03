#!/bin/bash

# This script contains commands used for both Status Function App and client part

az='docker run --rm --name az -v /home/user/.azure:/root/.azure -v /tmp/az:/tmp/az -it mcr.microsoft.com/azure-cli az '

TENANT_ID=$($az account show --query tenantId --output tsv | sed -e 's/[^a-z0-9-]//g')

BE_API_APP_NAME=dev-dsaad-status

# For Func App only:
# Collect information about thr tenant
FEDERATION_METADATA_URL="https://login.microsoftonline.com/$TENANT_ID/FederationMetadata/2007-06/FederationMetadata.xml"
ISSUER_URL=$(curl $FEDERATION_METADATA_URL --silent | sed -n 's/.*entityID="\([^"]*\).*/\1/p')
# Create the application registration, 
# defining a new application role and requesting access to read a user using the Graph API
BE_API_APP_ID=$($az ad app create --display-name $BE_API_APP_NAME --oauth2-allow-implicit-flow true \
  --native-app false --reply-urls http://localhost --identifier-uris "http://$API_APP_NAME" \
  --app-roles '  [ {  "allowedMemberTypes": [ "User" ], "description":"Access to drone status", "displayName":"Get Drone Device Status", "isEnabled":true, "value":"GetStatus" }]' \
  --required-resource-accesses '  [ {  "resourceAppId": "00000003-0000-0000-c000-000000000000", "resourceAccess": [ { "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d", "type": "Scope" } ] }]' \
  --query appId --output tsv | sed -e 's/[^a-z0-9-]//g')

# Create a service principal for the registered application
$az ad sp create --id $BE_API_APP_ID
$az ad sp update --id $BE_API_APP_ID --add tags "WindowsAzureActiveDirectoryIntegratedApp"

# Configure the Function App
#az webapp auth update --resource-group $RESOURCEGROUP --name $DRONE_STATUS_FUNCTION_APP_NAME --enabled true \
#--action LoginWithAzureActiveDirectory \
#--aad-token-issuer-url $ISSUER_URL \
#--aad-client-id $API_APP_ID
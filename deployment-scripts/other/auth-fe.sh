#!/bin/bash

az='docker run --rm --name az -v /home/user/.azure:/root/.azure -v /tmp/az:/tmp/az -it mcr.microsoft.com/azure-cli az '

TENANT_ID=$($az account show --query tenantId --output tsv | sed -e 's/[^a-z0-9-]//g')

# For client:
FE_API_APP_NAME=dev-dsaad-status-fe
# Create the application registration, requesting permission to access the Graph API and to impersonate a user when calling the drone status API 
BE_API_APP_ID=f5463387-b466-447e-916c-44fb337ae0a2
BE_API_IMPERSONATION_PERMISSION=$($az ad app show --id $BE_API_APP_ID --query "oauth2Permissions[?value == 'user_impersonation'].id" --output tsv  | sed -e 's/[^a-z0-9-]//g' )

REPLY_URLS="https://dev-dsaas-portal.azureedge.net"
CLIENT_APP_ID=$($az ad app create --display-name $FE_API_APP_NAME --oauth2-allow-implicit-flow true \
--native-app false --reply-urls "$REPLY_URLS" --identifier-uris "http://$FE_API_APP_NAME" \
--required-resource-accesses "  [ { \"resourceAppId\": \"$BE_API_APP_ID\", \"resourceAccess\": [ { \"id\": \"$BE_API_IMPERSONATION_PERMISSION\", \"type\": \"Scope\" } ] }, { \"resourceAppId\": \"00000003-0000-0000-c000-000000000000\", \"resourceAccess\": [ { \"id\": \"e1fe6dd8-ba31-4d61-89e7-88639da4683d\", \"type\": \"Scope\" } ] } ]" \
--query appId --output tsv | sed -e 's/[^a-z0-9-]//g')

$az ad sp create --id $CLIENT_APP_ID
$az ad sp update --id $CLIENT_APP_ID --add tags "WindowsAzureActiveDirectoryIntegratedApp"

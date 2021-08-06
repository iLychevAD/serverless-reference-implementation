#!/bin/bash

set -e

#az ad signed-in-user show
TENANT_ID=`az account show -o tsv --query 'tenantId'` # has double-quotes!
echo "tenant=$TENANT_ID"

# Status Function App
# Collect information about the tenant
BE_API_APP_NAME=dev-dsaas-status
BE_API_APP_DRONE_GET_STATUS_ROLE_NAME=GetStatus
FEDERATION_METADATA_URL="https://login.microsoftonline.com/$TENANT_ID/FederationMetadata/2007-06/FederationMetadata.xml"
BE_ISSUER_URL=$(curl $FEDERATION_METADATA_URL --silent | sed -n 's/.*entityID="\([^"]*\).*/\1/p')
# Create the application registration, 
# defining a new application role and requesting access to read a user using the Graph API
BE_API_APP_ID=$( az ad app list --display-name $BE_API_APP_NAME -o tsv --query "[?displayName=='$BE_API_APP_NAME'].appId" )
if [[ $BE_API_APP_ID == "" ]]
then
    echo "Create new '$BE_API_APP_ID' app"
    BE_API_APP_ID=$(az ad app create --display-name $BE_API_APP_NAME --oauth2-allow-implicit-flow true \
    --native-app false --reply-urls http://localhost --identifier-uris "http://$BE_API_APP_NAME" \
    --app-roles '  [ {  "allowedMemberTypes": [ "User" ], "description":"Access to drone status", "displayName":"Get Drone Device Status", "isEnabled":true, "value":"'$BE_API_APP_DRONE_GET_STATUS_ROLE_NAME'" }]' \
    --required-resource-accesses '  [ {  "resourceAppId": "00000003-0000-0000-c000-000000000000", "resourceAccess": [ { "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d", "type": "Scope" } ] }]' \
    --query appId --output tsv | sed -e 's/[^a-z0-9-]//g')
    # Create a service principal for the registered application, not used in ARM templates
    az ad sp create --id $BE_API_APP_ID
    az ad sp update --id $BE_API_APP_ID --add tags "WindowsAzureActiveDirectoryIntegratedApp"
fi
# The following is used in the Status Function App auth configuration
echo "aad-token-issuer-url=$BE_ISSUER_URL"
echo "aad-client-id=$BE_API_APP_ID"

echo "Prepare auth for Client app"

FE_API_APP_NAME=dev-dsaas-status-fe

BE_API_IMPERSONATION_PERMISSION=$( az ad app show --id $BE_API_APP_ID --query "oauth2Permissions[?value == 'user_impersonation'].id" --output tsv )

CDN_URL="${APPNAME}.azureedge.net"

CLIENT_APP_ID=$( az ad app list --display-name $FE_API_APP_NAME -o tsv --query "[?displayName=='$FE_API_APP_NAME'].appId" )
if [[ $CLIENT_APP_ID == "" ]]
then
    CLIENT_APP_ID=$(az ad app create --display-name $FE_API_APP_NAME --oauth2-allow-implicit-flow true \
    --native-app false --reply-urls "https://${CDN_URL}" --identifier-uris "http://$FE_API_APP_NAME" \
    --required-resource-accesses "  [ { \"resourceAppId\": \"$BE_API_APP_ID\", \"resourceAccess\": [ { \"id\": \"$BE_API_IMPERSONATION_PERMISSION\", \"type\": \"Scope\" } ] }, { \"resourceAppId\": \"00000003-0000-0000-c000-000000000000\", \"resourceAccess\": [ { \"id\": \"e1fe6dd8-ba31-4d61-89e7-88639da4683d\", \"type\": \"Scope\" } ] } ]" \
    --query appId --output tsv | sed -e 's/[^a-z0-9-]//g')

    echo "Create new '$FE_API_APP_NAME' app"
    az ad sp create --id $CLIENT_APP_ID
    az ad sp update --id $CLIENT_APP_ID --add tags "WindowsAzureActiveDirectoryIntegratedApp"
fi
# The following is injected into Client app's .env.production
echo "CLIENT_APP_ID=$CLIENT_APP_ID"


#!/bin/bash

STORAGE_ACCOUNT_NAME=devdsaasportalfe
LOCATION=westus2
RESOURCEGROUP=dev-dsaas-portal-fe


printf "\nCreate FE ResourceGroup\n"
[[ `az group list  --query "[?name=='$RESOURCEGROUP']" -o tsv` == "" ]] && \
  az group create -n $RESOURCEGROUP -l $LOCATION ||
  echo "ResourceGropup '$RESOURCEGROUP' already exists"

# Create the storage account 
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCEGROUP --location $LOCATION --kind StorageV2

# Enable static web site support for the storage account
az storage blob service-properties update --account-name $STORAGE_ACCOUNT_NAME --static-website --404-document 404.html --index-document index.html

# Retrieve the static website endpoint
WEB_SITE_URL=$(az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCEGROUP --query primaryEndpoints.web --output tsv)
WEB_SITE_HOST=$(echo $WEB_SITE_URL | sed -rn 's#.+//([^/]+)/?#\1#p')

# CDN
CDN_NAME=dev-dsaas-portal
# Create the CDN profile and endpoint
az cdn profile create --location westus --resource-group $RESOURCEGROUP --name $CDN_NAME  --sku Standard_Microsoft
CDN_ENDPOINT_HOST=$(az cdn endpoint create --location westus --resource-group $RESOURCEGROUP --profile-name $CDN_NAME --name $CDN_NAME \
--no-http --origin $WEB_SITE_HOST --origin-host-header $WEB_SITE_HOST \
--query hostName --output tsv)

# Configure custom caching rules 
az cdn endpoint update \
   -g $RESOURCEGROUP \
   --profile-name $CDN_NAME \
   -n $CDN_NAME \
   --set deliveryPolicy.description="" \
   --set deliveryPolicy.rules='[{"actions": [{"name": "CacheExpiration","parameters": {"cacheBehavior": "Override","cacheDuration": "366.00:00:00"}}],"conditions": [{"name": "UrlFileExtension","parameters": {"extensions": ["js","css","map"]}}],"order": 1}]'

CLIENT_URL="https://$CDN_ENDPOINT_HOST"
# See auth-fe.sh
### az ad app update --id $CLIENT_APP_ID --set replyUrls="[\"$CLIENT_URL\"]"

# ???
# az cdn endpoint update \
#    -g $RESOURCEGROUP \
#    --profile-name $CDN_NAME \
#    -n $CDN_NAME \
#    --set optimizationType="DynamicSiteAcceleration" \
#    --set probePath="/semver.txt"
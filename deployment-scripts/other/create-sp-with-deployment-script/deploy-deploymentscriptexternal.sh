#!/bin/bash
set -e

SCRIPT_DIR=`dirname $( realpath -s $0 )`
LOCATION="westus2"
ARTIFACTS_RESOURCEGROUP_NAME="artifacts"
RESOURCEGROUP=example-deployment-script 
ARTIFACTS_STORAGE_ACCOUNT_NAME="artifacts"
SCRIPT="create-sp.sh"
TPL="$SCRIPT_DIR/arm.json"

printf "\nCreate artifacts ResourceGroup\n"
[[ `az group list  --query "[?name=='$ARTIFACTS_RESOURCEGROUP_NAME']" -o tsv` == "" ]] && \
  az group create -n $ARTIFACTS_RESOURCEGROUP_NAME -l $LOCATION ||
  echo "ResourceGropup '$ARTIFACTS_RESOURCEGROUP_NAME' already exists"

printf "\nCreate artifacts storage account\n"
[[ `az storage account list  --query "[?name=='$ARTIFACTS_STORAGE_ACCOUNT_NAME']" -o tsv` == "" ]] && \
   az storage account create \
      --name $ARTIFACTS_STORAGE_ACCOUNT_NAME \
      --resource-group $ARTIFACTS_RESOURCEGROUP_NAME \
      --location $LOCATION \
      --sku Standard_LRS \
      --kind BlobStorage \
      --access-tier Hot ||
  echo "StorageAccount '$ARTIFACTS_STORAGE_ACCOUNT_NAME' already exists"

printf "\nCreate artifacts storage container\n"
#  `--only-show-errors` is to remove additional warning text from az cli output
[[ `az storage container list  --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME --only-show-errors --query "[?name=='artifacts']" -o tsv` == "" ]] && \
   az storage container create \
      --only-show-errors \
      --name artifacts \
      --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME \
      --public-access off || 
  echo "container 'artifacts' alreadfy exists"

echo "  uploading"
az storage blob upload \
   --validate-content \
   --only-show-errors \
   --file "$SCRIPT_DIR/$SCRIPT" \
   --container-name artifacts \
   --name $SCRIPT \
   --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME
echo "  obtaining SAS"
SAS_END_DATETIME=`date -d '+1 hour' '+%FT%T' -u` # +1 hour to the current time in UTC
SAS=$( az storage blob generate-sas \
   --only-show-errors \
   --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME \
   --container-name artifacts \
   --name $SCRIPT \
   --permissions r \
      --https-only \
      --full-uri \
   --expiry "${SAS_END_DATETIME}Z" | tail -1 | tr -d '"')

echo $SAS

echo "Validate ARM tpl:"
#az deployment group validate -g ${RESOURCEGROUP}  --template-file $TPL | jq '.'
echo "What-if"
az deployment group what-if \
   --mode Complete \
   -g ${RESOURCEGROUP} \
   --template-file $TPL \
   --parameters primaryScriptURI="$SAS"

echo "Deploying resources..."
DEPLOYMENT_NAME=$( echo `date -u '+%FT%TZ%z'` | tr -d ':' | tr -d '+')
# TODO: detect if is the first deploy and dont use rollback feature then
az deployment group create \
   --mode Complete \
   -g ${RESOURCEGROUP} \
   --name $DEPLOYMENT_NAME \
   --template-file $TPL \
   --parameters primaryScriptURI="$SAS"

echo "List deployment operations:"
az deployment operation group list --name $DEPLOYMENT_NAME -g ${RESOURCEGROUP} # | jq '.[] | .properties |  { provisioningOperation, provisioningState }'
echo "Deployment script result log:"
az deployment-scripts show-log -g ${RESOURCEGROUP} --name createSp

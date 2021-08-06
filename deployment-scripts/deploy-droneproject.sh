#!/bin/bash
set -e

GIT_COMMIT_SHA=`git rev-parse --short HEAD`

ENVIRONMENT=dev
PROJECT_NAME=dsaas-portal

COMMON_PREFIX=${ENVIRONMENT}-${PROJECT_NAME}

LOCATION=westus2
RESOURCEGROUP=$COMMON_PREFIX
APPNAME=$COMMON_PREFIX
APP_INSIGHTS_LOCATION=$LOCATION
COSMOSDB_DATABASE_NAME=$COMMON_PREFIX
COSMOSDB_DATABASE_COL=$COMMON_PREFIX
droneStatusClientStorageAccountName=`echo -n ${COMMON_PREFIX}clientapp | tr -d '-'`

prettyprint () {
    msg="###   $*  ###"
    edge=$(echo "$msg" | sed 's/./#/g')
    empty=$(echo "$msg" | sed 's/[^#]/ /g')
    printf "\n$edge\n$edge\n$empty\n"
    echo "$msg"
    printf "$empty\n$edge\n$edge\n\n"
}

printf "\nSourcing 'build.sh' to build Function App code\n"
. deployment-scripts/build-function-apps.sh

prettyprint "Sourcing 'prepare-auth.sh' to create auth principals"
. deployment-scripts/prepare-auth.sh

prettyprint "Creating distinct resource group and storage account for storing build artifacts"

ARTIFACTS_RESOURCEGROUP_NAME="${COMMON_PREFIX}-artifacts"
ARTIFACTS_STORAGE_ACCOUNT_NAME="`echo $COMMON_PREFIX | tr -d '-'`artifacts"

printf "\nCreate artifacts ResourceGroup...\n"
[[ `az group list  --query "[?name=='$ARTIFACTS_RESOURCEGROUP_NAME']" -o tsv` == "" ]] && \
  az group create -n $ARTIFACTS_RESOURCEGROUP_NAME -l $LOCATION ||
  echo "ResourceGropup '$ARTIFACTS_RESOURCEGROUP_NAME' already exists"

printf "\nCreate artifacts storage account...\n"
[[ `az storage account list  --query "[?name=='$ARTIFACTS_STORAGE_ACCOUNT_NAME']" -o tsv` == "" ]] && \
   az storage account create \
      --name $ARTIFACTS_STORAGE_ACCOUNT_NAME \
      --resource-group $RESOURCEGROUP-artifacts \
      --location $LOCATION \
      --sku Standard_LRS \
      --kind BlobStorage \
      --access-tier Hot ||
  echo "StorageAccount '$ARTIFACTS_STORAGE_ACCOUNT_NAME' already exists"

printf "\nCreate artifacts storage container...\n"
#  `--only-show-errors` is to remove additional warning text from az cli output
[[ `az storage container list  --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME --only-show-errors --query "[?name=='artifacts']" -o tsv` == "" ]] && \
   az storage container create \
      --only-show-errors \
      --name artifacts \
      --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME \
      --public-access off || 
  echo "container 'artifacts' alreadfy exists"

prettyprint "Upload built Function app code and obtain SAS tokens:"
for FUNC in `ls -1 ./built | grep zip`
do
   echo "  uploading $FUNC"
   az storage blob upload \
      --validate-content \
      --only-show-errors \
      --file `pwd`/built/${FUNC} \
      --container-name artifacts \
      --name $GIT_COMMIT_SHA/${FUNC} \
      --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME
   echo "  obtaining SAS for $FUNC"
   SAS_END_DATETIME=`date -d '+1 year' '+%FT%T' -u`
   SAS=$( az storage blob generate-sas \
      --only-show-errors \
      --account-name $ARTIFACTS_STORAGE_ACCOUNT_NAME \
      --container-name artifacts \
      --name "$GIT_COMMIT_SHA/${FUNC}" \
      --permissions r \
       --https-only \
       --full-uri \
      --expiry "${SAS_END_DATETIME}Z" | tail -1 | tr -d '"')
   if [[ $FUNC == *"Telemetry"* ]]
   then
       DroneTelemetryFunction_SAS="$SAS"
   else
       DroneStatusFunction_SAS="$SAS"
   fi
done

echo "Full SAS link for Telemetry func: ${DroneTelemetryFunction_SAS}"
echo "Full SAS link for Status func: ${DroneStatusFunction_SAS}"
# End with Function code

# Upload API Management ARM template as a template spec
# (https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-specs)
prettyprint "Upload API Management and client app ARM templates as a template specs"
az ts create \
  --only-show-errors \
  --yes `#confirm overwriting if we specidy the already existing version` \
  --name apim \
  --version "1.0.0" \
  --resource-group $RESOURCEGROUP-artifacts \
  --location $LOCATION \
  --template-file "./src/azuredeploy-apim.json" > /dev/null && \
echo "API Management ARM template Spec uploaded"

az ts create \
  --only-show-errors \
  --yes `#confirm overwriting if we specidy the already existing version` \
  --name clientapp \
  --version "1.0.0" \
  --resource-group $RESOURCEGROUP-artifacts \
  --location $LOCATION \
  --template-file "./src/azuredeploy-clientapp.json" > /dev/null && \
echo "Client app ARM template Spec uploaded"
# End ARM template specs

prettyprint "Create ResourceGroup $RESOURCEGROUP in $LOCATION region"
[[ `az group list  --query "[?name=='$RESOURCEGROUP']" -o tsv` == "" ]] && \
  az group create -n $RESOURCEGROUP -l $LOCATION ||
  echo "ResourceGropup '$RESOURCEGROUP' already exists"

prettyprint "What-if"
# az deployment group what-if \
#    --mode Complete \
#    -g ${RESOURCEGROUP} \
#    --template-file ./src/azuredeploy-backend-functionapps.json \
#    --parameters appName=${APPNAME} \
#    cosmosDatabaseName=${COSMOSDB_DATABASE_NAME} \
#    cosmosDatabaseCollection=${COSMOSDB_DATABASE_COL} \
#    droneStatusFunctionZipSas=$DroneStatusFunction_SAS \
#    droneTelemetryFunctionZipSas=$DroneTelemetryFunction_SAS \
#    apiManagementArmTplSpecResourceGroup=$ARTIFACTS_RESOURCEGROUP_NAME \
#    apiManagementArmTplSpecName=apim \
#    droneStatusFunctionAppAADTokenIssuerUrl=${BE_ISSUER_URL} \
#    droneStatusFunctionAppAADClientId=$BE_API_APP_ID \
#    tenantId=$TENANT_ID \
#    droneStatusClientStorageAccountName=$droneStatusClientStorageAccountName \
#    clientAppArmTplSpecName=clientapp \
#    tags='{"Environment":"dev"}'

prettyprint "Deploying resources..."
DEPLOYMENT_NAME=$( echo `date '+%F_%T_%z'` | tr -d ':' | tr -d '+')
# TODO: detect if is the first deploy and dont use rollback feature then
az deployment group create \
   --mode Complete \
   -g ${RESOURCEGROUP} \
   --name $DEPLOYMENT_NAME \
   --template-file ./src/azuredeploy-backend-functionapps.json \
   --parameters appName=${APPNAME} \
   cosmosDatabaseName=${COSMOSDB_DATABASE_NAME} \
   cosmosDatabaseCollection=${COSMOSDB_DATABASE_COL} \
   droneStatusFunctionZipSas=$DroneStatusFunction_SAS \
   droneTelemetryFunctionZipSas=$DroneTelemetryFunction_SAS \
   apiManagementArmTplSpecResourceGroup=$ARTIFACTS_RESOURCEGROUP_NAME \
   apiManagementArmTplSpecName=apim \
   droneStatusFunctionAppAADTokenIssuerUrl=${BE_ISSUER_URL} \
   droneStatusFunctionAppAADClientId=$BE_API_APP_ID \
   tenantId=$TENANT_ID \
   droneStatusClientStorageAccountName=$droneStatusClientStorageAccountName \
   clientAppArmTplSpecName=clientapp \
   tags='{"Environment":"dev"}' \
   #--rollback-on-error \

prettyprint "Finish the frontend client app - enable web static site, build and upload assets"
az storage blob service-properties update \
  --only-show-errors \
  --account-name ${droneStatusClientStorageAccountName} \
  --static-website --404-document 404.html --index-document index.html -o tsv

. deployment-scripts/build-and-upload-client-app.sh

# You will see the following message in web browser console if not acepted the consent:
# error occurred: AADSTS65001: The user or administrator has not consented to use the application with ID '...' named '...'.
# Send an interactive authorization request for this user and resource.
prettyprint "Open a browser on 'https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/authorize?client_id=${CLIENT_APP_ID}&response_type=code&redirect_uri=https%3A%2F%2F${CDN_URL}&response_mode=query
&scope=${BE_API_APP_ID}%2Fuser_impersonation&state=12345'"

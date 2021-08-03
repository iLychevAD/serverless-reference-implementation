#!/bin/bash
set -e

GIT_COMMIT_SHA=`git rev-parse --short HEAD`

COMMON_PREFIX=example-deployment-script
LOCATION=westus2
RESOURCEGROUP=$COMMON_PREFIX

TPL='./deployment-script-example.json'
TPL='./deployment-script-ad-example.arm.json'

printf "\nCreate ResourceGroup\n"
[[ `az group list  --query "[?name=='$RESOURCEGROUP']" -o tsv` == "" ]] && \
  az group create -n $RESOURCEGROUP -l $LOCATION ||
  echo "ResourceGropup '$RESOURCEGROUP' already exists"

echo "Validate ARM tpl:"
az deployment group validate -g ${RESOURCEGROUP}  --template-file ./deployment-script-example.json | jq '.'
echo "What-if"
az deployment group what-if \
   --mode Complete \
   -g ${RESOURCEGROUP} \
   --template-file $TPL

echo "Deploying resources..."
DEPLOYMENT_NAME=$( echo `date -u '+%FT%TZ%z'` | tr -d ':' | tr -d '+')
# TODO: detect if is the first deploy and dont use rollback feature then
az deployment group create \
   --mode Complete \
   -g ${RESOURCEGROUP} \
   --name $DEPLOYMENT_NAME \
   --template-file $TPL

echo "List deployment operations:"
az deployment operation group list --name $DEPLOYMENT_NAME -g ${RESOURCEGROUP} # | jq '.[] | .properties |  { provisioningOperation, provisioningState }'


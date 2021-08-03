#!/bin/bash

prettyprint "Building the web assets"

echo "$TENANT_ID $CLIENT_APP_ID $BE_API_APP_ID "
docker run --rm -it \
  --name droneapp-clientpp-nodejs-builder \
  -v `[[ -z "$HOST_PWD" ]] && pwd || echo "$HOST_PWD"`/src:/src \
  -v `[[ -z "$HOST_PWD" ]] && pwd || echo "$HOST_PWD"`/built/clientapp:/built \
  node:12-buster \
    /bin/bash -e -c '
    mkdir /tmp/src && cp -ar /src/ClientApp /tmp/src && cd /tmp/src/ClientApp && \
    npm install gatsby-cli  && \
    echo AZURE_TENANT_ID='$TENANT_ID' > .env.production && \
    echo AZURE_CLIENT_ID='$CLIENT_APP_ID' >> .env.production && \
    echo AZURE_API_CLIENT_ID='$BE_API_APP_ID' >> .env.production && \
    echo AZURE_API_URL='$APPNAME'.azure-api.net >> .env.production && \
    cat .env.production && \
    node ./node_modules/.bin/gatsby build && \
    rm -rf /built/* && cp -ar public/* /built/ && \
    echo Assets have been built
    '

prettyprint "Uploading assets"

UPLOAD_CMD=" az storage blob upload-batch -s ./built/clientapp --destination \$web --account-name ${droneStatusClientStorageAccountName} --only-show-errors "
${UPLOAD_CMD} --pattern "*.html" --content-type "text/html" && \
${UPLOAD_CMD} --pattern "*.js" --content-type "application/javascript" && \
${UPLOAD_CMD} --pattern "*.js.map" --content-type "application/octet-stream" && \
${UPLOAD_CMD} --pattern "*.json" --content-type "application/json" && \
echo "Assets have been uploaded"

#${UPLOAD_CMD} --pattern "*.txt" --content-type "text/plain"

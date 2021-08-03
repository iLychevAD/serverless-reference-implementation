#!/bin/bash
set -e

printf "\nBuild Function app code (zipped code is stored in the 'built' directory)\n"

mkdir -p ./built
docker run --rm -it \
  --name droneapp-dotnetsdk-builder \
  -v `[[ -z "$HOST_PWD" ]] && pwd || echo "$HOST_PWD"`/src:/src \
  -v `[[ -z "$HOST_PWD" ]] && pwd || echo "$HOST_PWD"`/built:/built \
  mcr.microsoft.com/dotnet/core/sdk:2.1 \
    /bin/bash -e -c '
    apt update && apt install -y -q zip; \
    mkdir /tmp/src && cp -ar /src/DroneStatus /src/DroneTelemetry /src/TelemetrySerialization /tmp/src; \
    for FUNC in DroneStatus/dotnet/DroneStatusFunctionApp DroneTelemetry/DroneTelemetryFunctionApp; \
    do \
      ZIP_NAME=`echo $FUNC | sed -e "s|.*/\(.*\)$|\1|" | sed -e "s/App//"`; \
      echo Building $ZIP_NAME; \
      dotnet publish /tmp/src/$FUNC \
        --configuration Release \
        --output `pwd`/${ZIP_NAME} && \
          (cd ${ZIP_NAME} && zip -r /built/${ZIP_NAME}.zip *)
    done'

# For notes:
#
# Alternatively, if you have Microsoft Visual Studio installed:
# dotnet publish /p:PublishProfile=Azure /p:Configuration=Release
#
# Deploy the function to the function app
# az functionapp deployment source config-zip \
#    --src /tmp/az/DroneStatusFunction.zip \
#    -g $RESOURCEGROUP \
#    -n ${DRONE_STATUS_FUNCTION_APP_NAME}

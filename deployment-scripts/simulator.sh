#!/bin/bash

# I run az cli from inside a Docker container,
# remove this string if you dont.
az='docker run --rm --name az -v /home/user/.azure:/root/.azure -v /tmp/az:/tmp/az -it mcr.microsoft.com/azure-cli az '

DRONE_APP_PREFIX="dev-dsaas-portal"

# list the send keys
EVENT_HUB_CONNECTION_STRING=$($az eventhubs eventhub authorization-rule keys list \
     -g ${DRONE_APP_PREFIX} \
     --eventhub-name ${DRONE_APP_PREFIX}  \
     --namespace-name ${DRONE_APP_PREFIX} \
     -n send \
     --query primaryConnectionString --output tsv)

docker run --rm -it \
  --name droneapp-dotnetsdk-simulator \
  -v `pwd`/src:/src \
  mcr.microsoft.com/dotnet/core/sdk:2.1 \
     /bin/bash -e -c '
          export SIMULATOR_PROJECT_PATH=/src/DroneSimulator/Serverless.Simulator/Serverless.Simulator.csproj; \
          mkdir /tmp/src && cp -ar /src/DroneSimulator /tmp/src; \
          dotnet build $SIMULATOR_PROJECT_PATH
               SECONDS_TO_RUN=25 \
               GENERATE_KEYFRAME_GAP=10000 \
               NUMBER_OF_DEVICES=5 \
               EVENT_HUB_CONNECTION_STRING="'$EVENT_HUB_CONNECTION_STRING'" \
               dotnet run --project $SIMULATOR_PROJECT_PATH
          '



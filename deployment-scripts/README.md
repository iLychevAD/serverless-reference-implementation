## Integrated deployment bash script and ARM templates.

Here you can find an integrated (though splitted into several files) bash script `deploy-droneproject.sh` that allows to deploy Drone app in a single run. It hugely utilizes Azure ARM templates.

The main difference to the original project https://github.com/mspnp/serverless-reference-implementation is that a lot of manual steps (with `az cli`) are moved into ARM templates and it doesnt depend on Azure DevOps pipelines to perform deployment.

## How to run

### Prerequisites
You have `az cli` and `docker` installed and `az cli` is configured to access some Azure subscription.

### Run
In the `deploy-droneproject.sh` tailor the variables `ENVIRONMENT`, `PROJECT_NAME`, `COMMON_PREFIX`, `LOCATION`. They are used inside scripts and ARM templates to name and place resources. 

In the repository root directory do

```deployment-scripts/deploy-droneproject.sh```

*Note:* the script is idempotent, if it fails at some step, just fix an issue and retry it.

### Explanation

The script `deploy-droneproject.sh` performs the following steps:

1. builds Drone Status and Telemetry Function Apps code using docker (see `build-function-apps.sh`)
2. runs `prepare-auth.sh` that creates Application registrations and injects corresponding environment variables for further usage by scripts and ARM templates (see original deployment README.md for details)
3. with `az cli` creates a separate Resource Group and Storage resources inside it to store Function App code, uploads the code
4. uploads `azuredeploy-apim.json` and `azuredeploy-clientapp.json` as ARM template specs (they are used as linked templates to create API Management and resources for hosting Client App web assets)
5. with `az cli` creates a main Resource Group to deploy all the application resources into
6. optionally runs `az deployment group what-if`
7. finally, it deploys all the resources of the application using the `azuredeploy-backend-functionapps.json` template (note that I dont use `azuredeploy-backend-functionapps-v2.json` at all)
8. finalizes the Client App installation - builds assets using docker container and uploads them into a dedicated Storage account created at the previous step, enables web statis site feature for the latter
9. finally, shows the link to the consent page (see original deployment README.md for details)

There is also `simulator.sh` script that you can use to emulate some workload on to the application. Adjust the settings inside the scipt as proper for you. The original README.md contains no much info regarding the simulator but what the latter does is just sends some data to the Events Hub endpoint. If anything is OK you then can see that data inserted into CosmosDB instance and fetch it through Client App web UI. 
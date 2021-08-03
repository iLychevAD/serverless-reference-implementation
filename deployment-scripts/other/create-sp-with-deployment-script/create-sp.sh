#!/bin/bash
set -x 
printf "SP\n\n"

az ad sp list --verbose
echo "az ad list end"

echo `az ad sp list` > $AZ_SCRIPTS_OUTPUT_PATH

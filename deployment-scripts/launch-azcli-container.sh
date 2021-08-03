#!/bin/bash
docker run --rm --name az-interactive \
  -v /var/run/docker.sock:/var/run/docker.sock `# Docker-in-docker` \
  -v ~/.azure:/root/.azure \
  -v `pwd`:/pwd \
  -v /tmp/az:/tmp/az \
  -w /pwd \
  --env HOST_PWD=`echo -n $(pwd)` \
  -it mcr.microsoft.com/azure-cli bash -c 'apk add coreutils docker && bash'

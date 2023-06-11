#!/bin/bash

packer init ./packer-server/
packer validate -var-file="./variables.server.pkrvars.hcl" ./packer-server/
packer build -timestamp-ui -var-file="./variables.server.pkrvars.hcl" ./packer-server/


#!/bin/bash

packer init ./packer/
packer validate -var-file="./variables.pkrvars.hcl" ./packer/
packer build -timestamp-ui -var-file="./variables.pkrvars.hcl" ./packer/


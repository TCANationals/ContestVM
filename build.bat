@echo off
packer init .\packer\
packer validate .\packer\
packer build -timestamp-ui -var-file=".\variables.pkrvars.hcl" .\packer\

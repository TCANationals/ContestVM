$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

Import-Module Packer -DisableNameChecking
Import-Module TCA -DisableNameChecking

if (-not (TCA-PrivateUrlSupported)) {
    Exit 0
}

$HorizonAgentExe = "Omnissa-Horizon-Agent-x86_64-2503-8.15.0-14304348675.exe"

TCA-DownloadFile "$HorizonAgentExe"

# Install Horizon Agent
Write-Host "Installing VMware Horizon Agent"
Start-Process -Wait -FilePath "$PackerDownloads\$HorizonAgentExe" -ArgumentList '/s /v"/qn REBOOT=ReallySuppress URL_FILTERING_ENABLED=1 VDM_VC_MANAGED_AGENT=1 ADDLOCAL=ALL REMOVE=ClientDriveRedirection,SerialPortRedirection,ScannerRedirection,SmartCard"'

# Remove agent installer
Remove-Item -Path "$PackerDownloads\$HorizonAgentExe"

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\tca-env.ps1

if (-not (TCA-PrivateUrlSupported)) {
    Exit 0
}

$HorizonAgentExe = "VMware-Horizon-Agent-x86_64-2203-8.5.0-19564166.exe"

TCA-DownloadFile "$HorizonAgentExe"

# Install Horizon Agent
Start-Process -Wait -FilePath "$PackerDownloads\$HorizonAgentExe" -ArgumentList '/s /v"/qn REBOOT=ReallySuppress URL_FILTERING_ENABLED=1 VDM_VC_MANAGED_AGENT=1 ADDLOCAL=ALL REMOVE=ClientDriveRedirection,SerialPortRedirection,ScannerRedirection,SmartCard"'

# Remove agent installer
Remove-Item -Path "$PackerDownloads\$HorizonAgentExe"

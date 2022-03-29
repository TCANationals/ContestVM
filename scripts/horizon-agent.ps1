$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\tca-env.ps1

$HorizonAgentExe = "VMware-Horizon-Agent-x86_64-2111-8.4.0-19446757.exe"

TCA-DownloadFile "$HorizonAgentExe"

# Install Horizon Agent
Start-Process -Wait -FilePath "$PackerDownloads\$HorizonAgentExe" -ArgumentList '/s /v"/qn REBOOT=ReallySuppress URL_FILTERING_ENABLED=1 VDM_VC_MANAGED_AGENT=1 ADDLOCAL=ALL REMOVE=ClientDriveRedirection,SerialPortRedirection,ScannerRedirection,SmartCard"'

# Remove agent installer
Remove-Item -Path "$PackerDownloads\$HorizonAgentExe"

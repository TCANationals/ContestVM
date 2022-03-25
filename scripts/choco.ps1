$ChocolateyServerInstall = "https://chocolatey.org/install.ps1"
#$CholateyServer = "http://<your_server>/chocolatey"


Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString($ChocolateyServerInstall))

# Install RSAT tools
# active directory user mgmt
DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
# group policy management
DISM.exe /Online /add-capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# Base chocolatey tools
choco install chocolatey-core.extension -y
choco install chocolatey-windowsupdate.extension -y

# Install the base system apps
choco install sysinternals -y
choco install vlc -y
choco install adobereader -y
choco install winrar -y
choco install notepadplusplus -y
choco install googlechrome -y
choco install microsoft-windows-terminal -y
choco install microsoft-office-deployment -y --params="'/64bit /DisableUpdate:TRUE /Product:ProPlus2021Volume,VisioPro2021Volume,ProjectPro2021Volume /Exclude:OneDrive,Lync,Groove,Teams'"

#choco install $APP1 -s $CholateyServer -y

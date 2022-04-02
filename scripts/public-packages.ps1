. C:\Packer\Scripts\tca-env.ps1

# Install the core system apps
choco install laps -y --params='"/ALL"'
choco install sysinternals -y
choco install vlc -y
choco install adobereader -y
choco install winrar -y
choco install notepadplusplus -y
choco install microsoft-windows-terminal -y
choco install microsoft-office-deployment -y --params="'/64bit /DisableUpdate:TRUE /Product:ProPlus2021Volume,VisioPro2021Volume,ProjectPro2021Volume /Exclude:OneDrive,Lync,Groove,Teams'"
choco install tableau-desktop --version=2022.1.0 -y # update finalize when changing version
choco install vscode -y
choco install speedtest -y

# Setup bginfo on logon
$BgInfoVal = ('"C:\ProgramData\chocolatey\bin\Bginfo64.exe" "' + $PackerConfig + '\logon.bgi" /timer:0 /silent /nolicprompt')
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "BGInfo" -Value "$BgInfoVal" -ea SilentlyContinue -wa SilentlyContinue

# Install packages that are auto-updated (since Choco gallary can fall behind & we trust these sources)
# Google Chrome
$ChromeFilename = "googlechromestandaloneenterprise64.msi"
Download-File "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi" "$PackerDownloads\$ChromeFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$ChromeFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$ChromeFilename"

# MS PowerBI
Download-File "https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe" "$PackerDownloads\PBIDesktopSetup_x64.exe"
Start-Process -Wait -FilePath "$PackerDownloads\PBIDesktopSetup_x64.exe" -ArgumentList "-quiet -norestart ACCEPT_EULA=1"
Remove-Item -Path "$PackerDownloads\PBIDesktopSetup_x64.exe"

# Install from other sources
# Get latest timer desktop release from GitHub
Get-GithubLatestRelease "TCANationals/timer-desktop" "TCA-Timer-Web-Setup" "TimerSetup.exe"
Start-Process -Wait -FilePath "$PackerDownloads\TimerSetup.exe" -ArgumentList '/s'
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "TCA Timer" -Value "C:\Program Files\TCA Timer\TCA Timer.exe" -ea SilentlyContinue -wa SilentlyContinue
Remove-Item -Path "$PackerDownloads\TimerSetup.exe"

# Zoom VDI (requires plugin on the client)
$ZoomFilename = "ZoomInstallerVDI.msi"
Download-File "https://zoom.us/download/vdi/5.9.6/ZoomInstallerVDI.msi" "$PackerDownloads\$ZoomFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$ZoomFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$ZoomFilename"

# Install RSAT tools
# active directory user mgmt
DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
# group policy management
DISM.exe /Online /add-capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

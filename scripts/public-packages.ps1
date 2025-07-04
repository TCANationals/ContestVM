﻿$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

Import-Module Packer -DisableNameChecking
Import-Module TCA -DisableNameChecking

# Install the core system apps
Choco-Install -PackageName choco-protocol-support
Choco-Install -PackageName vcredist-all
#Choco-Install -PackageName laps -ArgumentList "--params='`"/ALL`"'"
Choco-Install -PackageName lxrunoffline
Choco-Install -PackageName sysinternals -ArgumentList "--ignore-checksums"
Choco-Install -PackageName vlc
#Choco-Install -PackageName adobereader
Choco-Install -PackageName winrar
Choco-Install -PackageName notepadplusplus
Choco-Install -PackageName microsoft-office-deployment -ArgumentList "--params=`"'/64bit /DisableUpdate:TRUE /Product:ProPlus2024Volume,VisioPro2024Volume,ProjectPro2024Volume /Exclude:OneDrive,Lync,Groove,Teams,OneNote'`""
#Choco-Install -PackageName tableau-desktop -ArgumentList "--version=2023.2.2" # update finalize when changing version
Choco-Install -PackageName vscode
Choco-Install -PackageName speedtest
Choco-Install -PackageName speedtest-by-ookla
Choco-Install -PackageName sql-server-management-studio
Choco-Install -PackageName python -ArgumentList "--version=3.10.8", "--params", '"/NoLockdown"'
Choco-Install -PackageName nodejs-lts
Choco-Install -PackageName r
Choco-Install -PackageName cutepdf
#Choco-Install -PackageName microsoft-windows-terminal

# Install office from TCA cache since MS keeps changing the URL
#$OfficeDeploymentFilename = "officedeploymenttool_16501-20196.exe"
#Download-File "https://files.tcanationals.com/deps/$OfficeDeploymentFilename" "$PackerDownloads\$OfficeDeploymentFilename"

# Install music apps
#Choco-Install -PackageName amazon-music
#Choco-Install -PackageName spotify -ArgumentList "--ignore-checksums"

# Lock down tools directory for lxrunoffline
Set-DirectoryUserAcls "C:\tools"

# Grant all users access to python directory
TCA-AuthUserFullAccess 'C:\Python310'

# Install BgAssist to refresh background in VDI
#Download-File "https://files.tcanationals.com/deps/BgAssist.exe" "$PackerDownloads\BgAssist.exe"
#Download-File "https://files.tcanationals.com/deps/BgAssist-Config.exe" "$PackerDownloads\BgAssist-Config.exe"
#Download-File "https://files.tcanationals.com/deps/NLog.dll" "$PackerDownloads\NLog.dll"

# Setup bginfo on logon
# Note - use BGinfo directory and not the choco shim, the shim causes a CLI window to appear to the user on launch
$BgInfoVal = ('"C:\ProgramData\chocolatey\lib\sysinternals\tools\Bginfo64.exe" "' + $PackerConfig + '\logon.bgi" /timer:0 /silent /nolicprompt')
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "BGInfo" -Value "$BgInfoVal" -ea SilentlyContinue -wa SilentlyContinue

# Install packages that are auto-updated (since Choco gallary can fall behind & we trust these sources)
# Google Chrome
$ChromeFilename = "googlechromestandaloneenterprise64.msi"
Download-File "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi" "$PackerDownloads\$ChromeFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$ChromeFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$ChromeFilename"

# Tableau Desktop - update shortcut when version changes
$TableauFilename = "TableauDesktopSetup.exe"
Download-File "https://files.tcanationals.com/cache/TableauDesktop-64bit-2025-1-2.exe" "$PackerDownloads\$TableauFilename"
Start-Process -Wait -FilePath "$PackerDownloads\$TableauFilename" -ArgumentList "/quiet /norestart ACCEPTEULA=1 AUTOUPDATE=0 SENDTELEMETRY=0"
Remove-Item -Path "$PackerDownloads\$TableauFilename"

# MS PowerBI
Download-File "https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe" "$PackerDownloads\PBIDesktopSetup_x64.exe"
Start-Process -Wait -FilePath "$PackerDownloads\PBIDesktopSetup_x64.exe" -ArgumentList "-quiet -norestart ACCEPT_EULA=1"
Remove-Item -Path "$PackerDownloads\PBIDesktopSetup_x64.exe"

# Install Windows Terminal from GitHub
# Leave file behind for future installs
Download-File "https://github.com/microsoft/terminal/releases/download/v1.22.11141.0/Microsoft.WindowsTerminal_1.22.11141.0_8wekyb3d8bbwe.msixbundle" "$PackerDownloads\WindowsTerminal.msixbundle"
Add-AppxProvisionedPackage -Online -SkipLicense -PackagePath "$PackerDownloads\WindowsTerminal.msixbundle"

# Install from other sources
# Get latest timer desktop release from GitHub
Get-GithubLatestRelease "TCANationals/timer-desktop" "TCA-Timer-Web-Setup" "TimerSetup.exe"
$Timer7zFile = Get-GithubLatestRelease "TCANationals/timer-desktop" 'tca-timer-desktop-.*-x64.nsis.7z$' ""
Start-Process -Wait -FilePath "$PackerDownloads\TimerSetup.exe" -ArgumentList '/s'
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "TCA Timer" -Value "C:\Program Files\TCA Timer\TCA Timer.exe" -ea SilentlyContinue -wa SilentlyContinue
Remove-Item -Path "$PackerDownloads\TimerSetup.exe"
Remove-Item -Path "$PackerDownloads\$Timer7zFile"

# Zoom VDI (requires plugin on the client)
$ZoomFilename = "ZoomInstallerVDI.msi"
Download-File "https://zoom.us/download/vdi/6.4.10.26150/ZoomInstallerVDI.msi?archType=x64" "$PackerDownloads\$ZoomFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$ZoomFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$ZoomFilename"

# Install RSAT tools
# active directory user mgmt
DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
# group policy management
DISM.exe /Online /add-capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# PowerAutomate at the end since it restarts the PC
#Choco-Install -PackageName powerautomatedesktop -ArgumentList "--ignore-checksums"

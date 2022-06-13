. C:\Packer\Scripts\tca-env.ps1

# Install manual Appx deps
$UWPDesktop64Filename = "Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.Appx"
Download-File "https://files.tcanationals.com/deps/$UWPDesktop64Filename" "$PackerDownloads\$UWPDesktop64Filename"
DISM.EXE /Online /Add-ProvisionedAppxPackage /PackagePath:"$PackerDownloads\$UWPDesktop64Filename" /SkipLicense
Remove-Item -Path "$PackerDownloads\$UWPDesktop64Filename"

# Install the core system apps
choco install choco-protocol-support -y
choco install laps -y --params='"/ALL"'
choco install lxrunoffline -y
choco install sysinternals -y
choco install vlc -y
choco install adobereader -y
choco install winrar -y
choco install notepadplusplus -y
choco install microsoft-office-deployment -y --params="'/64bit /DisableUpdate:TRUE /Product:ProPlus2021Volume,VisioPro2021Volume,ProjectPro2021Volume /Exclude:OneDrive,Lync,Groove,Teams'"
choco install tableau-desktop --version=2022.1.0 -y # update finalize when changing version
choco install vscode -y
choco install speedtest -y
choco install sql-server-management-studio -y
choco install python --version=3.10.4 -y --params "/NoLockdown"
choco install nodejs-lts -y
choco install git -y

# Install music apps
#choco install amazon-music -y
#choco install spotify --ignore-checksums -y

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

# Get latest Windows Terminal from Github
Get-GithubLatestRelease "microsoft/terminal" 'Microsoft.WindowsTerminal_Win10.*msixbundle$' "Terminal.msixbundle"
Add-AppProvisionedPackage -online -packagepath "$PackerDownloads\Terminal.msixbundle" -skiplicense
# Do not remove package, since this will be installed for every user
#Remove-Item -Path "$PackerDownloads\Terminal.msixbundle"

# Zoom VDI (requires plugin on the client)
$ZoomFilename = "ZoomInstallerVDI.msi"
Download-File "https://zoom.us/download/vdi/5.10.2/ZoomInstallerVDI.msi" "$PackerDownloads\$ZoomFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$ZoomFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$ZoomFilename"

# Install RSAT tools
# active directory user mgmt
DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
# group policy management
DISM.exe /Online /add-capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

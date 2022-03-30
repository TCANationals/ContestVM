$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\tca-env.ps1

# VMware DEM to ensure profiles are stored on central server
$DEMFilename = "VMwareDynamicEnvironmentManagerEnterprise211110.4x64.msi"
TCA-DownloadFile "$DEMFilename"
#msiexec.exe /i "$PackerDownloads\$DEMFilename" /qn ADDLOCAL=FlexEngine,FlexProfilesSelfSupport,FlexManagementConsole
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$DEMFilename"" /qn ADDLOCAL=FlexEngine,FlexProfilesSelfSupport,FlexManagementConsole"
Remove-Item -Path "$PackerDownloads\$DEMFilename"

# LanSchool student installer
$LSStudentFilename = "Student_91050.msi"
TCA-DownloadFile "$LSStudentFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$LSStudentFilename"" /qn ADVANCED_OPTIONS=1 STEALTH_MODE=1 AD_SECURE_MODE=1 CHANNEL=1 ONLY_INSTALL_UPGRADE=1"
Remove-Item -Path "$PackerDownloads\$LSStudentFilename"

# Google Chrome
$ChromeFilename = "googlechromestandaloneenterprise64.msi"
Download-File "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi" "$PackerDownloads\$ChromeFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$ChromeFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$ChromeFilename"

# MS PowerBI
Download-File "https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup_x64.exe" "$PackerDownloads\PBIDesktopSetup_x64.exe"
Start-Process -Wait -FilePath "$PackerDownloads\PBIDesktopSetup_x64.exe" -ArgumentList "-quiet -norestart ACCEPT_EULA=1"
Remove-Item -Path "$PackerDownloads\PBIDesktopSetup_x64.exe"

# Pearson Certiport Compass, for IC3 exam
# This generates a random admin account since Certiport needs local admin to run
$CertAdminPass = Get-RandomPassword 8
$CertAdminSecurePass = ConvertTo-SecureString "$CertAdminPass" -AsPlainText -Force
Write-Output $CertAdminPass | Out-File -FilePath "$PackerLogs\CertiAdminPass.txt"
Create-NewLocalAdmin "CertiportAdmin" $CertAdminSecurePass
$CompassArgList = ('/Silent Path="C:\Certiport\Compass" /TestCenterID 90063004 /CertiportID 90063004 /TestCenterName "SkillsUSA" /LanguageCode ENU /ImpersonationUser "CertiportAdmin" /ImpersonationPassword "' + $CertAdminPass + '"')
Write-Output $CompassArgList | Out-File -FilePath "$PackerLogs\CertiArgs.txt"
$CompassFilename = "Compass_Setup_19.0.2.907.exe"
TCA-DownloadFile "$CompassFilename"
Start-Process -Wait -FilePath "$PackerDownloads\$CompassFilename" -ArgumentList "$CompassArgList"
Remove-Item -Path "$PackerDownloads\$CompassFilename"

# Get latest timer desktop release from GitHub
Get-GithubLatestRelease "TCANationals/timer-desktop" "TCA-Timer-Web-Setup" "TimerSetup.exe"
Start-Process -Wait -FilePath "$PackerDownloads\TimerSetup.exe" -ArgumentList '/s'
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "TCA Timer" -Value "C:\Program Files\TCA Timer\TCA Timer.exe" -ea SilentlyContinue -wa SilentlyContinue
Remove-Item -Path "$PackerDownloads\TimerSetup.exe"

# Install RSAT tools
# active directory user mgmt
DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
# group policy management
DISM.exe /Online /add-capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

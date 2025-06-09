# Install software only available on private TCA server, these are all licensed and not available to the public

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\tca-env.ps1

if (-not (TCA-PrivateUrlSupported)) {
    Exit 0
}

# VMware DEM to ensure profiles are stored on central server
$DEMFilename = "Omnissa-DEM-Enterprise-2412-10.14-x64.msi"
TCA-DownloadFile "$DEMFilename"
#msiexec.exe /i "$PackerDownloads\$DEMFilename" /qn ADDLOCAL=FlexEngine,FlexProfilesSelfSupport,FlexManagementConsole
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$DEMFilename"" /qn ADDLOCAL=FlexEngine,FlexProfilesSelfSupport,FlexManagementConsole"
Remove-Item -Path "$PackerDownloads\$DEMFilename"

$DEMHDFilename = "Omnissa-DEM-Helpdesk-Support-Tool-2412-10.14-x64.msi"
TCA-DownloadFile "$DEMHDFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$DEMHDFilename"" /qn"
Remove-Item -Path "$PackerDownloads\$DEMHDFilename"

# LanSchool student installer
$LSStudentFilename = "Student_91050.msi"
TCA-DownloadFile "$LSStudentFilename"
Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i ""$PackerDownloads\$LSStudentFilename"" /qn ADVANCED_OPTIONS=1 STEALTH_MODE=1 AD_SECURE_MODE=1 CHANNEL=1 ONLY_INSTALL_UPGRADE=1"
Remove-Item -Path "$PackerDownloads\$LSStudentFilename"

# Pearson Certiport Compass, for IC3 exam
# This generates a random admin account since Certiport needs local admin to run
Write-Output "Creating dedicated admin account for Compass"
$CertAdminPass = Get-RandomPassword 12
$CertAdminSecurePass = ConvertTo-SecureString "$CertAdminPass" -AsPlainText -Force
Create-NewLocalAdmin "CertiportAdmin" $CertAdminSecurePass

$CompassArgList = ('/Silent Path="C:\Certiport\Compass" /TestCenterID 90063004 /CertiportID 90063004 /TestCenterName "SkillsUSA" /LanguageCode ENU /ImpersonationUser "CertiportAdmin" /ImpersonationPassword "' + $CertAdminPass + '"')
$CompassFilename = "Compass_Setup_19.0.2.1508.exe"
TCA-DownloadFile "$CompassFilename"
Start-Process -Wait -FilePath "$PackerDownloads\$CompassFilename" -ArgumentList "$CompassArgList"
Remove-Item -Path "$PackerDownloads\$CompassFilename"

$CompassExamsFilename = "IC3_GS6_June_9_25.exe"
TCA-DownloadFile "$CompassExamsFilename"
Start-Process -Wait -FilePath "$PackerDownloads\$CompassExamsFilename"
Remove-Item -Path "$PackerDownloads\$CompassExamsFilename"

# Lock down Certiport directory
Write-Output "Locking down Certiport directory"
Set-DirectoryUserAcls "C:\Certiport"
Set-DirectoryUserAcls "C:\Certiport\Compass"

# Grant all users access to Compass directory
TCA-AuthUserFullAccess 'C:\Certiport\Compass'

# Deploy VM, assumes hard-coded directory for VMware Player
$vmOvaFilename = "ShortCircuit.ova"
$OvfArgList = ('-dm=twoGbMaxExtentSparse --acceptAllEulas -n=TroubleshootingVM "' + "$TCAPrivateUrl/$vmOvaFilename" + '" "' + "$PackerPublic" + '"')
Write-Output "Deploying VM"
Start-Process -Wait -FilePath "${Env:ProgramFiles(x86)}\VMware\VMware Player\OVFTool\ovftool.exe" -ArgumentList "$OvfArgList"
# Update network to NAT
$vmxData = Get-Content -Path "$PackerPublic\TroubleshootingVM\TroubleshootingVM.vmx" -Raw
$vmxData -Replace 'bridged', 'nat' | Set-Content -Path "$PackerPublic\TroubleshootingVM\TroubleshootingVM.vmx"
# Grant all users write access
TCA-AuthUserFullAccess "$PackerPublic"
Write-Output "Finished deploying VM"

$vmOvaFilename = "Whiteout.ova"
$OvfArgList = ('-dm=twoGbMaxExtentSparse --acceptAllEulas -n=WhiteoutVM "' + "$TCAPrivateUrl/$vmOvaFilename" + '" "' + "$PackerPublic" + '"')
Write-Output "Deploying VM Whiteout"
Start-Process -Wait -FilePath "${Env:ProgramFiles(x86)}\VMware\VMware Player\OVFTool\ovftool.exe" -ArgumentList "$OvfArgList"
# Update network to NAT
$vmxData = Get-Content -Path "$PackerPublic\WhiteoutVM\WhiteoutVM.vmx" -Raw
$vmxData -Replace 'bridged', 'nat' | Set-Content -Path "$PackerPublic\WhiteoutVM\WhiteoutVM.vmx"
# Grant all users write access
TCA-AuthUserFullAccess "$PackerPublic"
Write-Output "Finished deploying VM Whiteout"

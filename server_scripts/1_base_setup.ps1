. C:\Packer\Scripts\tca-env.ps1

# The script bootstraps new Windows Server instances
# It is run on all Windows Servers after base OS setup and before other server scripts

# Install base powershell modules
Install-PackageProvider -Name NuGet -Force -Scope AllUsers -Confirm:$False
Install-Module -Name PowerShellGet -Force -Scope AllUsers -Allowclobber -Confirm:$False
Install-Module -Name PackageManagement -Force -Scope AllUsers -Allowclobber -Confirm:$False
Install-Module -Name PSPKI -Force -Scope AllUsers -Allowclobber -Confirm:$False

# Install other PS modules
Install-Module -Name AdminToolbox.EndpointManagement -Scope AllUsers -Allowclobber -Confirm:$False -Force
Install-Module -Name PolicyFileEditor -Scope AllUsers -Allowclobber -Confirm:$False -Force
Install-Module -Name ADCSTemplate -Scope AllUsers -Allowclobber -Confirm:$False -Force
Install-Module -Name AWS.Tools.Installer -Scope AllUsers -Allowclobber -Confirm:$False -Force

# Install AWS modules
Install-AWSToolsModule -Name AWS.Tools.SSOAdmin,AWS.Tools.SSO,AWS.Tools.IdentityStore -CleanUp -Confirm:$False -Force

# Base tools
Choco-Install -PackageName winrar
Choco-Install -PackageName googlechrome
Choco-Install -PackageName notepadplusplus
Choco-Install -PackageName sysinternals

# Install RSAT tools
# active directory user mgmt
DISM.exe /Online /add-capability /CapabilityName:Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
# group policy management
DISM.exe /Online /add-capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# Setup bginfo on logon
# Note - use BGinfo directory and not the choco shim, the shim causes a CLI window to appear to the user on launch
$BgInfoVal = ('"C:\ProgramData\chocolatey\lib\sysinternals\tools\Bginfo64.exe" "' + $PackerConfig + '\logon.bgi" /timer:0 /silent /nolicprompt')
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "BGInfo" -Value "$BgInfoVal" -ea SilentlyContinue -wa SilentlyContinue

# Disable CTRL+ALT+DEL in logon
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableCAD /t REG_DWORD /d 1 /f
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DisableCAD /t REG_DWORD /d 1 /f

# Run debloat script
Write-Host "Downloading ContestVM repo"
cd $PackerStaging
git clone https://github.com/TCANationals/ContestVM vm

# Auto-load TCA env into powershell
Set-Content -Path $PsHome\Profile.ps1 -Force -Value '. C:\Packer\Scripts\tca-env.ps1'

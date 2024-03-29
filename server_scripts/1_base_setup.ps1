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

# Disable CTRL+ALT+DEL in logon
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableCAD /t REG_DWORD /d 1 /f
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DisableCAD /t REG_DWORD /d 1 /f

# Auto-load TCA env into powershell
Set-Content -Path $PsHome\Profile.ps1 -Force -Value '. C:\Packer\Scripts\tca-env.ps1'

# The script bootstraps new Windows Server instances
# It is run on all Windows Servers before any other scripts

# Install base powershell modules
Install-PackageProvider -Name NuGet -Force -Scope AllUsers -Confirm:$False
Install-Module -Name PowerShellGet -Force -Scope AllUsers -Allowclobber -Confirm:$False

# Install other PS modules
Install-Module -Name AdminToolbox.EndpointManagement -Scope AllUsers -Allowclobber -Confirm:$False -Force
Install-Module -Name PolicyFileEditor -Scope AllUsers -Allowclobber -Confirm:$False -Force
Install-Module -Name ADCSTemplate -Scope AllUsers -Allowclobber -Confirm:$False -Force

$ChocolateyServerInstall = "https://chocolatey.org/install.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString($ChocolateyServerInstall))

# Base chocolatey tools
choco install chocolatey-core.extension -y
choco install chocolatey-windowsupdate.extension -y

# Base tools
choco install winrar -y
choco install googlechrome -y
choco install notepadplusplus -y

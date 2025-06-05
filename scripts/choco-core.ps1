. C:\Packer\Scripts\tca-env.ps1

Write-Host "Installing WMIC"
try {
    # this is needed for Win 11 24H2 since WMIC isn't installed by default
    dism.exe /online /add-capability /capabilityname:WMIC~~~~
} catch {
    Write-Host "Unable to install WMIC, ignoring..."
}

Write-Host "Installing Chocolatey"
$ChocolateyServerInstall = "https://community.chocolatey.org/install.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString($ChocolateyServerInstall))

# Base chocolatey tools
Choco-Install -PackageName chocolatey-core.extension
Choco-Install -PackageName chocolatey-windowsupdate.extension

# Install NuGet
Write-Host "Installing NuGet package provider"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Install git
Write-Host "Installing git"
Choco-Install -PackageName git

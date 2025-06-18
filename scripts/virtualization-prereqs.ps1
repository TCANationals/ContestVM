$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. "C:\Packer\Scripts\tca-env.ps1"

# Enable VM support
Write-Host "Enabling WSL and VM Windows features"
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart

# Install WSL 2
# Requires WSL windows feature to be installed already (with system restart)
try {
    Choco-Install -PackageName wsl2 -RetryCount 3 -ArgumentList "--ignore-package-exit-codes", "--params", '"/Version:2 /Retry:true"'
} catch {
    Write-Host "WSL install failed, ignoring..."
}

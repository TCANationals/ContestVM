Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

. A:\windows-env.ps1
$PackageDir = 'A:\'

$rundate = Get-Date
Write-Output "Script: bootstrap-packerbuild.ps1 Starting at: $rundate"

# Setup packer Powershell module
$allPowershellModulePaths = [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::Machine)
$powershellModulePath = $allPowershellModulePaths.Split(";")[0] # get first global module path
$tcaModulePath = Join-Path -Path $powershellModulePath -ChildPath "TCA"
$packerModulePath = Join-Path -Path $powershellModulePath -ChildPath "Packer"

New-Item -ItemType Directory -Force -Path $tcaModulePath
New-Item -ItemType Directory -Force -Path $packerModulePath

if (-not (Test-Path "$packerModulePath\Packer.psm1" )) {
  Copy-Item A:\windows-env.ps1 $packerModulePath\Packer.psm1
}
if (-not (Test-Path "$tcaModulePath\TCA.psm1" )) {
  Copy-Item A:\tca-env.ps1 $tcaModulePath\TCA.psm1
}

# Create Packer Log Directories if they don't exist already.
Create-PackerStagingDirectories
if (-not (Test-Path "$PackerScripts\choco-cleaner.ps1" )) {
  Copy-Item A:\choco-cleaner.ps1 $PackerScripts\choco-cleaner.ps1
}
if (-not (Test-Path "$PackerScripts\clean-profiles.ps1" )) {
  Copy-Item A:\clean-profiles.ps1 $PackerScripts\clean-profiles.ps1
}
if (-not (Test-Path "$PackerScripts\tca-uri.ps1" )) {
  Copy-Item A:\tca-uri.ps1 $PackerScripts\tca-uri.ps1
}

# Copy binary config files
if (-not (Test-Path "$PackerDownloads\BgAssist-Config.exe.config" )) {
  #Copy-Item A:\BgAssist-Config.exe.config $PackerDownloads\BgAssist-Config.exe.config
}
if (-not (Test-Path "$PackerConfig\defaultassociations.xml" )) {
  Copy-Item A:\defaultassociations.xml $PackerConfig\defaultassociations.xml
}
if (-not (Test-Path "$PackerConfig\logon.bgi" )) {
  Copy-Item A:\logon.bgi $PackerConfig\logon.bgi
}
if (-not (Test-Path "$PackerConfig\susa_black.bmp" )) {
  Copy-Item A:\susa_black.bmp $PackerConfig\susa_black.bmp
}

if (-not (Test-Path "$PackerLogs\PrivatiseNetAdapters.installed")) {
  Set-AllNetworkAdaptersPrivate
  Touch-File "$PackerLogs\PrivatiseNetAdapters.installed"
}


if (-not (Test-Path "$PackerLogs\NextDNS_CA_Root.installed")) {
  Write-Output "Adding `"NextDNS CA Root`""
  $vproc = Start-Process certutil @SprocParms -ArgumentList '-enterprise -f -v -AddStore "Root" "A:\nextdns_ca.crt"'
  $vproc.WaitForExit()
}
Touch-File "$PackerLogs\NextDNS_CA_Root.installed"

# Upgrade PowershellGet
Install-Module -Name PowerShellGet -Force -AllowClobber

Write-Output "Packer setup complete"

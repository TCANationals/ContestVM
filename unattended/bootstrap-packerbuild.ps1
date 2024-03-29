<#
  .SYNOPSIS
	Bootstrap the Packer build
  .DESCRIPTION
  First Logon script actions after the Windows ISO has been installed.
  Script to perform the minimal actions needed to bring the host online with winrm
  i.e, install the hypervisor tools, network adaptor mods and necessary reg fixes.
  The windows update is deferred until a later stage.
  This means that more immediate feedback is given to packer that the OS load itself
  is sound.
#>

param (
    [string]$HyperVisor = "vmware",
    [string]$AdminUsername = "Administrator",
    [string]$AdminPassword = "PackerAdmin"
)
$ErrorActionPreference = 'Stop'

. A:\windows-env.ps1
$PackageDir = 'A:\'

$rundate = Get-Date
Write-Output "Script: bootstrap-packerbuild.ps1 Starting at: $rundate"

# Disabling WinRM Service as this will be explicitly enabled as the final action on this script.
Write-Output "Ensure WinRM is disabled"
Set-Service -StartupType Disabled -Name WinRM

# Create Packer Log Directories if they don't exist already.
Create-PackerStagingDirectories
if (-not (Test-Path "$PackerScripts\windows-env.ps1" )) {
  Copy-Item A:\windows-env.ps1 $PackerScripts\windows-env.ps1
}
if (-not (Test-Path "$PackerScripts\choco-cleaner.ps1" )) {
  Copy-Item A:\choco-cleaner.ps1 $PackerScripts\choco-cleaner.ps1
}
if (-not (Test-Path "$PackerScripts\clean-profiles.ps1" )) {
  Copy-Item A:\clean-profiles.ps1 $PackerScripts\clean-profiles.ps1
}
if (-not (Test-Path "$PackerScripts\tca-env.ps1" )) {
  Copy-Item A:\tca-env.ps1 $PackerScripts\tca-env.ps1
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
if (-not (Test-Path "$PackerConfig\nextdns_ca.crt" )) {
  Copy-Item A:\nextdns_ca.crt $PackerConfig\nextdns_ca.crt
}

# Create Scheduled Task so this repeatedly until we have finished.
if (-not (Test-Path "$PackerLogs\BootstrapSchedTask.installed")) {
  Write-Output "Create Bootstrap Scheduled Task"
  schtasks /create /tn PackerBootstrap /rl HIGHEST /RU SYSTEM /F /SC ONSTART /DELAY 0000:20 /TR 'cmd /c c:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe -sta -WindowStyle Hidden -ExecutionPolicy Bypass -NonInteractive -NoProfile -File A:\bootstrap-packerbuild.ps1 >> C:\Packer\Logs\bootstrap-packerbuild.log 2>&1'
  Touch-File "$PackerLogs\BootstrapSchedTask.installed"
}

# Enable WSUS - this is being put at the top of the script deliberately as a recycle of wuauserv is
# required - this most reliable way to do this is with a reboot so we want to get this out the way first
# to prevent windows update starting anything.
# DO NOT USE WSUS for Windows-10 (changed from Jan 2020) as too many SSU issues with it.
# So WSUS is primarily for servicing Windows 2012r2 and then mainly for slipstreaming purposes
# Same seems to apply to win-2012 so disabling for this too.
if ($WindowsVersion -like $WindowsServer2012 -or $WindowsVersion -like $WindowsServer2016 ) {
  Write-Output "Bypassing WSUS - Go Direct to Microsoft for updates"
  Disable-WindowsAutoUpdate
}
else {
  Enable-UpdatesFromInternalWSUS
}

if (-not (Test-Path "$PackerLogs\HyperVisorExtensions.installed")) {
  Write-Output "Installing HyperVisor ($HyperVisor) Extensions/Tools"

  # This is a Windows 10 only workaround to make sure the trusted installer is actually running.
  # This needs to be done early on in the initialisation sequence well before we apply updates.
  # Not certain, but this appears to improve the reliability of the windows update.
  if ($WindowsVersion -Like $WindowsServer2016) {
    Set-Service "trustedinstaller" -StartupType Automatic -ErrorAction SilentlyContinue
  }

  if (($WindowsVersion -Like $WindowsServer2016) -or ($WindowsVersion -Like $WindowsServer2012R2)) {
    # Block Windows Store updates during the build process (until GPO policies are in place)
    Write-Host "Stop Windows Store Updates"
    reg add HKLM\Software\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f
    reg add HKLM\Software\Policies\Microsoft\WindowsStore /v AutoDownload /t REG_DWORD /d 2 /f
    reg add HKLM\Software\Policies\Microsoft\WindowsStore /v RemoveWindowsStore /t REG_DWORD /d 1 /f
  }

  switch ($HyperVisor) {
    "vmware" {
      # VMWare installs only
      # Install VMWare tools at this point as we will need to reboot afterwars.
      Write-Output "Installing VMWare Tools"
      if ("$ARCH" -eq "x86") {
        $VMToolsInstaller = "E:\setup.exe"
      } else {
        $VMToolsInstaller = "E:\setup64.exe"
      }
      $vproc = Start-Process "$VMToolsInstaller" @SprocParms -ArgumentList '/s /v "/qn REBOOT=R ADDLOCAL=ALL REMOVE=Hgfs"'
      $vproc.WaitForExit()
      break
    }
  }
  Touch-File "$PackerLogs\HyperVisorExtensions.installed"
  Write-Output "Forcing Reboot to fully install Hypervisor extension/toolset and restart wuauserv"
  Invoke-Reboot
}

if (-not (Test-Path "$PackerLogs\PrivatiseNetAdapters.installed")) {
  Set-AllNetworkAdaptersPrivate
  Touch-File "$PackerLogs\PrivatiseNetAdapters.installed"
}

# if (($WindowsVersion -like $WindowsServer2008) -or ($WindowsVersion -like $WindowsServer2008r2)) {
#   if (-not (Test-Path "$PackerLogs\AddTrust_External_CA_Root.installed")) {
#     Write-Output "Adding `"AddTrust External CA Root`" for Win-2008/2008r2/7 SSL Issue"
#     $vproc = Start-Process certutil  @SprocParms -ArgumentList '-addstore -f "AuthRoot" "A:\AddTrust_External_CA_Root.cer"'
#     $vproc.WaitForExit()
#   }
#   Touch-File "$PackerLogs\AddTrust_External_CA_Root.installed"
# }

# Special for Windows 2008/2008r2 only to enable the JSON parsing assemblies. This was originally in the
# platform-packages.ps1 script which had been moved to the bootstrap phase. Unfortunately that caused too
# many side effects with the WirRM configuration, so platform-packages was moved back to the windows udpate
# phase and the .Net 3.5 enablement was moved here.

if ($WindowsVersion -like $WindowsServer2008) {
  if (-not (Test-Path "$PackerLogs\NET35.Installed"))
  {
    Write-Output "Setting network adapters to private"
    $networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))
    $connections = $networkListManager.GetNetworkConnections()

    # Install .Net 3.5.1
    Write-Output ".Net 3.5.1"
    Download-File "https://artifactory.delivery.puppetlabs.net/artifactory/generic/buildsources/windows/win-2008-ps2/dotnetfx35setup.exe"  "$ENV:TEMP\dotnetfx35setup.exe"
    Start-Process -Wait "$ENV:TEMP\dotnetfx35setup.exe" -ArgumentList "/q"
    Write-Output ".Net 3.5.1 Installed"
    Touch-File "$PackerLogs\NET35.Installed"
    if (Test-PendingReboot) { Invoke-Reboot }
  }
}
if ($WindowsVersion -like $WindowsServer2008r2 -and $WindowsInstallationType -eq "Server" ) {
  if (-not (Test-Path "$PackerLogs\NET35.installed"))
  {
    # Enable .Net 3.5 (needed for Puppet csc compiles)
    Write-Output "Enable .Net 3.5"
    DISM /Online /Enable-Feature /FeatureName:NetFx3
    Touch-File "$PackerLogs\NET35.installed"
    if (Test-PendingReboot) { Invoke-Reboot }
  }
}

# Set WinRM service to start automatically (not delayed)
Write-Output "Enabling WinRM Service"
Set-Service "WinRM" -StartupType Automatic -Status Running
Write-Output "Checking/Waiting for running WinRm"
$WinRmService = Get-Service -Name WinRM
$WinRmService.WaitForStatus("Running",'00:02:00')

# Enable Remote Desktop (with reduce authentication resetting here again)
Write-Output "Enable Remote Desktop"
Enable-RemoteDesktop -DoNotRequireUserLevelAuthentication
netsh advfirewall firewall add rule name="Remote Desktop" dir=in localport=3389 protocol=TCP action=allow

# Add WinRM Firewall Rule
Write-Output "Setting up winrm"
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow

# WinRM Configuration.
Write-Output "Enable PS-Remoting -Force"
$enableArgs=@{Force=$true}
try {
 $command=Get-Command Enable-PSRemoting
  if($command.Parameters.Keys -contains "skipnetworkprofilecheck"){
      $enableArgs.skipnetworkprofilecheck=$true
  }
}
catch {
  $global:error.RemoveAt(0)
}
try {
  Enable-PSRemoting @enableArgs
}
catch {
  Write-Output "Ignoring PSRemoting Error"
}

Write-Output "Enable WSMandCredSSP"
Enable-WSManCredSSP -Force -Role Server

# Upgrade NuGet and PowershellGet
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PowerShellGet -Force

# Needed for Win-2008r2
# Generally increase all of these parameters to improve file upload reliability
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
winrm set winrm/config/winrs '@{MaxProcessesPerShell="2147483647"}'
winrm set winrm/config/winrs '@{MaxShellsPerUser="2147483647"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'

# NOTE - This is insecure but can be shored up in later customisation.  Required for Vagrant and other provisioning tools
Write-Output "WinRM Settings"
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Bootstrap Cycle complete - delete this task.
Write-Output "Deleting Bootstrap Scheduled Task"
schtasks /Delete /tn PackerBootstrap /F

Write-Output "WinRM setup complete"

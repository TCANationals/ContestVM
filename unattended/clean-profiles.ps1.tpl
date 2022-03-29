<#
  .SYNOPSIS
	Clean up all user profile directories
#>

$ErrorActionPreference = 'Stop'

. C:\Packer\Scripts\windows-env.ps1

$rundate = Get-Date
Write-Output "Script: clean-profiles.ps1 Starting at: $rundate"

if (-not (Test-Path "$PackerLogs\ProfileClean.installed")) {
  Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq '${winrm_username}' } | Remove-CimInstance
  Touch-File "$PackerLogs\ProfileClean.installed"
}

# Set WinRM service to start automatically (not delayed)
Write-Output "Enabling WinRM Service"
Set-Service "WinRM" -StartupType Automatic -Status Running
Write-Output "Checking/Waiting for running WinRm"
$WinRmService = Get-Service -Name WinRM
$WinRmService.WaitForStatus("Running",'00:02:00')

# Bootstrap Cycle complete - delete this task.
Write-Output "Deleting Bootstrap Scheduled Task"
schtasks /Delete /tn PackerClean /F

Write-Output "WinRM setup complete"

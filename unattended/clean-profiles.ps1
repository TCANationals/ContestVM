<#
  .SYNOPSIS
	Clean up all user profile directories
#>

$ErrorActionPreference = 'Stop'

. C:\Packer\Scripts\windows-env.ps1

$rundate = Get-Date
Write-Output "Script: clean-profiles.ps1 Starting at: $rundate"

if (-not (Test-Path "$PackerLogs\ProfileClean.installed")) {
  Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq 'Administrator' } | Remove-CimInstance
  Touch-File "$PackerLogs\ProfileClean.installed"
}

# Delete TCA URI file
if (Test-Path "C:\Packer\Scripts\tca-uri.ps1") {
  Remove-Item -Path C:\Packer\Scripts\tca-uri.ps1 -Force
}

# Init tca-env for powershell
Set-Content -Path $PsHome\Profile.ps1 -Force -Value '. C:\Packer\Scripts\tca-env.ps1'

# Set Administrator password as blank
Set-LocalUser -Name "Administrator" -Password ([securestring]::new())

# Clean autologon
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonSID -Value ""
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "LocalAdmin"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value ""
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name LastUsedUsername -Value "LocalAdmin"

# Release IP
C:\Packer\Downloads\OSOT.exe -v -f 11

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

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

Import-Module Packer -DisableNameChecking
Import-Module TCA -DisableNameChecking

# List of allowed shortcuts, all others will be removed
$AllowedShortcuts = @(
  'Speech Recognition.lnk'
  'Calculator.lnk'
  'Math Input Panel.lnk'
  'Notepad.lnk'
  'Paint.lnk'
  'Snipping Tool.lnk'
  'Windows Media Player.lnk'
  'Wordpad.lnk'
  'Access.lnk'
  'Acrobat Reader DC.lnk'
  'Excel.lnk'
  'Google Chrome.lnk'
  'Notepad++.lnk'
  'OneNote.lnk'
  'Outlook.lnk'
  'PowerPoint.lnk'
  'Project.lnk'
  'Publisher.lnk'
  'TCA Timer.lnk'
  'Visio.lnk'
  'Word.lnk'
  'Magnify.lnk'
  'Narrator.lnk'
  'On-Screen Keyboard.lnk'
  'Windows PowerShell.lnk'
)

if (Test-Path "$PackerLogs\Mock.Platform" ) {
  Write-Output "Test Platform Build - exiting"
  exit 0
}

# Clean up all downloads & ensure we have all folders
#Remove-Tree $PackerDownloads
#Create-PackerStagingDirectories

$SpaceAtStart = [Math]::Round( ((Get-WmiObject win32_logicaldisk | where { $_.DeviceID -eq $env:SystemDrive }).FreeSpace)/1GB, 2)

#Set all CleanMgr VolumeCache keys to StateFlags = 0 to prevent cleanup. After, set the proper keys to 2 to allow cleanup.
$SubKeys = Get-Childitem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches
Foreach ($Key in $SubKeys)
{
    Set-ItemProperty -Path $Key.PSPath -Name $CleanMgrStateFlags -Value $CleanMgrStateFlagNoAction
}

# Clean Chocolatey
Write-Output "Cleaning up Chocolatey"
PowerShell.exe -NoProfile -ExecutionPolicy unrestricted -Command "& 'C:\Packer\Scripts\choco-cleaner.ps1'"

# Clean desktop shortcuts
Remove-Shortcuts

# Clean remaining shortcuts (leave whitelist)
$shortcuts = Get-Shortcuts
$shortcuts | Where-Object{$_.ShortcutName -notin $AllowedShortcuts} | Remove-Item -ErrorAction SilentlyContinue -Force

# Remove Active Setup for Chrome & Edge
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}" -Force -ea SilentlyContinue -wa SilentlyContinue #edge
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{8A69D345-D564-463c-AFF1-A69D9E530F96}" -Force -ea SilentlyContinue -wa SilentlyContinue #chrome

# Cleanup Windows Update area after all that
# Clean the WinSxS area - actual action depends on OS Level - full DISM commands only available from 2012R2 and later.
Write-Output "Cleaning up WinxSx updates"
If ($WindowsVersion -like $WindowsServer2008) {
  Write-Output "Windows 2008 - Reduced cleanup"
  compcln /quiet
}
ElseIf ($WindowsVersion -like $WindowsServer2008R2 ) {
  # Windows 2008R2/Win-7 - just set registry keys for cleanmgr utility
  reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup"       /v $CleanMgrStateFlags /t REG_DWORD /d $CleanMgrStateFlagClean /f
  reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Service Pack Cleanup" /v $CleanMgrStateFlags /t REG_DWORD /d $CleanMgrStateFlagClean /f
}
ElseIf ($WindowsVersion -like $WindowsServer2012) {
  # Note /ResetBase option is not available on Windows-2012, so need to screen for this.
  dism /online /Cleanup-Image /StartComponentCleanup
  dism /online /cleanup-image /SPSuperseded
} else {
  dism /online /Cleanup-Image /StartComponentCleanup /ResetBase
  dism /online /cleanup-image /SPSuperseded
}

If ($WindowsVersion -like $WindowsServer2008) {
  Write-Output "Skipping CleanMgr for Windows 2008"
}
ElseIf ( $WindowsServerCore ) {
  Write-Output "Skipping Clean-Mgr as GUI not installed (Core Installation)."
}
ElseIf ($WindowsVersion -like $WindowsServer2016) {
  Write-Output "Skipping Clean-Mgr for Win-10/2016 as it tends to hang"
}
else {
  # Set registry keys for all the other cleanup areas we want to address with cleanmgr - fairly comprehensive cleanup
  $cleankeyprefix = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
  $cleanmgrgroups = @(
    'Active Setup Temp Folders',
    'Downloaded Program Files',
    'Internet Cache Files',
    'Memory Dump Files',
    'Old ChkDsk Files',
    'Previous Installations',
    'Recycle Bin',
    'Setup Log Files',
    'System error memory dump files',
    'System error minidump files',
    'Temporary Files',
    'Temporary Setup Files',
    'Upgrade Discarded Files',
    'Windows Error Reporting Archive Files',
    'Windows Error Reporting Queue Files',
    'Windows Error Reporting System Archive Files',
    'Windows Error Reporting System Queue Files',
    'Windows Upgrade Log Files'
  )
  $cleanmgrgroups | % { reg.exe ADD "$cleankeyprefix\$_" /v $CleanMgrStateFlags /t REG_DWORD /d $CleanMgrStateFlagClean /f }

  # Run Cleanmgr utility
  Write-Output "Running CleanMgr with Sagerun:$CleanMgrSageSet"
  Start-Process -Wait "cleanmgr" -ArgumentList "/sagerun:$CleanMgrSageSet"
}

# Clean up files (including those not addressed by cleanmgr)
# Use Try/Catch in preference to SilentlyContinue as this needs to be PS 2 compatible
# to avoid aborting on locked files etc in Win-2008r2
Write-Output "Clearing Files"
@(
    "$ENV:LOCALAPPDATA\temp\*",
    "$ENV:WINDIR\logs",
    "$ENV:WINDIR\temp\*",
    "$ENV:WINDIR\SoftwareDistribution\Download\*",
    "$ENV:USERPROFILE\AppData\Local\Microsoft\Windows\WER\ReportArchive",
    "$ENV:USERPROFILE\AppData\Local\Microsoft\Windows\WER\ReportQueue",
    "$ENV:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportArchive",
    "$ENV:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportQueue"
) | ForceFullyDelete-Path -LogFile "$PackerLogs\clean-basefiles.log"

# clear log from above (can be over 75 MB)
Remove-Item -Force -Path "$PackerLogs\clean-basefiles.log"

# Clearing Logs
Write-Output "Clearing Logs"
wevtutil clear-log Application
wevtutil clear-log Security
wevtutil clear-log Setup
wevtutil clear-log System

# Display Free Space Statistics at end
$SpaceAtEnd = [Math]::Round( ((Get-WmiObject win32_logicaldisk | where { $_.DeviceID -eq $env:SystemDrive }).FreeSpace)/1GB, 2)
$SpaceReclaimed = [Math]::Round( ($SpaceAtEnd - $SpaceAtStart),2)

Write-Output "Cleaning Complete"
Write-Output "Starting Free Space $SpaceAtStart GB"
Write-Output "Current Free Space $SpaceAtEnd GB"
Write-Output "Reclaimed $SpaceReclaimed GB"

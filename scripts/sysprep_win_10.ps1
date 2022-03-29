$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\windows-env.ps1

try {
    Download-File "https://files.tcanationals.com/packer_tools/VMwareHorizonOSOptimizationTool-x86_64-1.0_2111.exe"  "C:\Packer\Downloads\OSOT.exe"
    Download-File "https://files.tcanationals.com/packer_tools/LGPO.exe"  "C:\Packer\Downloads\LGPO.exe"
    Download-File "https://files.tcanationals.com/packer_tools/sdelete64.exe"  "C:\Packer\Downloads\sdelete64.exe"

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 0
    netsh advfirewall set allprofiles state on
    C:\Packer\Downloads\OSOT.exe -o all-item -SyncHkcuToHku Enable -VisualEffect Balanced -Notification Disable -WindowsSearch SearchBoxAsIcon -StoreApp Keep-all -SmartScreen Disable -Background "#000000" EnableCustomization -v
    # finalize image (except for zero disk space 7 & release IP 11)
    C:\Packer\Downloads\OSOT.exe -v -f 0 1 2 3 4 5 6 8 9 10
    #Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList "/generalize /oobe /quiet /quit"
    # Disable CTRL+ALT+DEL logon (OSOT will re-enable)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DisableCAD -Value 1

    # Customize default user preferences
    reg load "HKU\temp" c:\users\default\ntuser.dat
    # Disable most used apps from appearing in the start menu
    reg add "HKU\temp\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_TrackProgs" /t REG_DWORD /d 0 /f
    # Show file extensions
    reg add "HKU\temp\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f
    # Show all taskbar notifications
    reg add "HKU\temp\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "EnableAutoTray" /t REG_DWORD /d 0 /f
    reg unload "hku\temp"

    # Setup task to delete Packer user profile on reboot (task will enable WinRM once finished)
    Write-Output "Ensure WinRM is disabled"
    Set-Service -StartupType Disabled -Name WinRM
    Write-Output "Create Clean Scheduled Task"
    schtasks /create /tn PackerClean /rl HIGHEST /ru "SYSTEM" /F /SC ONSTART /DELAY 0000:20 /TR 'cmd /c c:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe -sta -WindowStyle Hidden -ExecutionPolicy Bypass -NonInteractive -NoProfile -File C:\Packer\Scripts\clean-profiles.ps1 >> C:\Packer\Logs\clean-packerbuild.log 2>&1'
}
catch {
    Write-Host
    Write-Host "Something went wrong:" 
    Write-Host ($PSItem.Exception.Message)
    Write-Host

    # Sleep for 2 minutes so you can see the errors before the VM is destroyed by Packer.
    Start-Sleep -Seconds 120

    Exit 1
}

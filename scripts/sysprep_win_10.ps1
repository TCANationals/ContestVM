$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\windows-env.ps1

try {
    Download-File "https://files.tcanationals.com/packer_tools/VMwareHorizonOSOptimizationTool-x86_64-1.0_2111.exe"  "C:\Packer\Downloads\OSOT.exe"
    Download-File "https://files.tcanationals.com/packer_tools/LGPO.exe"  "C:\Packer\Downloads\LGPO.exe"
    Download-File "https://files.tcanationals.com/packer_tools/sdelete64.exe"  "C:\Packer\Downloads\sdelete64.exe"

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 0
    netsh advfirewall set allprofiles state on
    C:\Packer\Downloads\OSOT.exe -o all-item -SyncHkcuToHku Enable -VisualEffect Balanced -Notification Disable -WindowsSearch SearchBoxAsIcon -StoreApp Keep-all -SmartScreen Disable -v
    # finalize image (except for zero disk space 7 & release IP 11)
    C:\Packer\Downloads\OSOT.exe -v -f 0 1 2 3 4 5 6 8 9 10
    #Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList "/generalize /oobe /quiet /quit"
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

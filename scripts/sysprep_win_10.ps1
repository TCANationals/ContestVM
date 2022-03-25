$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

#Start-Transcript C:\sysprep.txt

try {
    Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList "/generalize /oobe /quiet /quit"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 0
    netsh advfirewall set allprofiles state on
}
catch {
    Write-Host
    Write-Host "Something went wrong:" 
    Write-Host ($PSItem.Exception.Message)
    Write-Host

    # Sleep for 60 minutes so you can see the errors before the VM is destroyed by Packer.
    Start-Sleep -Seconds 3600

    Exit 1
}

Start-Sleep -Seconds 60

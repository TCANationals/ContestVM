$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\tca-env.ps1

#Start-Transcript C:\customise.txt

# Prevent defender from getting in the way of Packer files
Set-MpPreference -ExclusionPath $PackerStaging

try {
    # Install EndpointManagement extensions
    Write-Host "Installing AdminToolbox.EndpointManagement"
    Install-Module -Name AdminToolbox.EndpointManagement -Scope AllUsers -Allowclobber -Confirm:$False -Force
    Write-Host "Installing PolicyFileEditor"
    Install-Module -Name PolicyFileEditor -Scope AllUsers -Allowclobber -Confirm:$False -Force

    # Run debloat script
    Write-Host "Running Win11Debloat"
    cd $PackerTemp
    Write-Output "> Downloading Win11Debloat..."
    git clone https://github.com/Raphire/Win11Debloat/ Win11Debloat
    Write-Output "> Running Win11Debloat..."
    $debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File .\Win11Debloat\Win11Debloat.ps1 -RunDefaults -RemoveCommApps -RemoveW11Outlook -RemoveGamingApps -DisableDVR -ClearStart -DisableTelemetry -DisableBing -DisableSuggestions -DisableLockscreenTips -RevertContextMenu -HideSearchTb -DisableCopilot -DisableWidgets -HideChat -ShowKnownFileExt -Silent"
    $debloatProcess.WaitForExit()
    Write-Output "> Cleaning up..."
    Remove-Item -LiteralPath "Win11Debloat" -Force -Recurse

    # Disable screensaver and screen off
    Write-Host "Disabling Screensaver"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name ScreenSaveActive -Value 0 -Type DWord
    & powercfg -x -monitor-timeout-ac 0
    & powercfg -x -monitor-timeout-dc 0

    # Enable RDP
    & netsh advfirewall firewall add rule name="Open Port 3389" dir=in action=allow protocol=TCP localport=3389
    & reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

    # Disable password expiration for your local admin account.
    Write-Host "Setting admin account to not expire..."
    wmic useraccount where "name='Administrator'" set PasswordExpires=FALSE

    # Set power plan to High Performance.
    Write-Host "Setting power plan to high performance..."
    $p = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High Performance'"      
    powercfg /setactive ([string]$p.InstanceID).Replace("Microsoft:PowerPlan\{","").Replace("}","")

    # Load HKEY_USERS hive
    Write-Host "Loading HKEY_USERS..."
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    # Setup HKU Default keys if not exist
    if(-not (Test-Path -Path "HKU:\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")){
        # code to create new key
        New-Item "HKU:\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "Advanced" -Force
    }

    # Show file extensions in Windows Explorer.
    Write-Host "Enabling file extensions in Windows Explorer..."
    Set-Itemproperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Verbose
    Set-Itemproperty -Path "HKU:\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Verbose

    # Show all notifications in task bar
    Write-Host "Enabling file extensions in Windows Explorer..."
    Set-Itemproperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Verbose
    Set-Itemproperty -Path "HKU:\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Verbose

    # Disable VMware Tools icon (using reg to ensure key is auto-created)
    & reg add "HKEY_LOCAL_MACHINE\Software\VMware, Inc.\VMware Tools" /v ShowTray /t REG_DWORD /d 0 /f

    # Kill & remove OneDrive if found
    cmd /c "START /wait taskkill /F /IM OneDrive.exe"
    if (Test-Path "$Env:WinDir\SysWOW64\OneDriveSetup.exe") {
        cmd /c "$Env:WinDir\SysWOW64\OneDriveSetup.exe /uninstall"
    }
    if (Test-Path "$Env:WinDir\System32\OneDriveSetup.exe") {
        cmd /c "$Env:WinDir\System32\OneDriveSetup.exe /uninstall"
    }
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

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

. C:\Packer\Scripts\tca-env.ps1

try {
    Download-File "https://files.tcanationals.com/packer_tools/VMwareHorizonOSOptimizationTool-x86_64-1.0_2111.exe"  "C:\Packer\Downloads\OSOT.exe"
    Download-File "https://files.tcanationals.com/packer_tools/LGPO.exe"  "C:\Packer\Downloads\LGPO.exe"
    Download-File "https://files.tcanationals.com/packer_tools/sdelete64.exe"  "C:\Packer\Downloads\sdelete64.exe"

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoLogonCount -Value 0
    netsh advfirewall set allprofiles state on
    C:\Packer\Downloads\OSOT.exe -o all-item -SyncHkcuToHku Enable -VisualEffect Balanced -Notification Disable -WindowsSearch SearchBoxAsIcon -StoreApp Keep-all -SmartScreen Disable -Background "#000000" -v
    # finalize image (except for zero disk space 7 & release IP 11)
    C:\Packer\Downloads\OSOT.exe -v -f 0 1 2 3 4 5 6 8 9 10
    # Disable CTRL+ALT+DEL on logon
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DisableCAD -Value 1
    # Hide office update option
    reg add "HKLM\Software\Policies\Microsoft\Office\16.0\Common\OfficeUpdate" /v "HideEnableDisableUpdates" /t REG_DWORD /d 1 /f
    reg add "HKLM\Software\Policies\Microsoft\Office\16.0\Common\OfficeUpdate" /v "HideUpdateNotifications" /t REG_DWORD /d 1 /f
    # Set Chrome policies
    # LANschool student extension
    reg add "HKLM\Software\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "honjcnefekfnompampcpmcdadibmjhlk;https://clients2.google.com/service/update2/crx" /f
    # VMware multimedia extension
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Name "2" -Value "ljmaegmnepbgjekghdfkgegbckolmcok;https://clients2.google.com/service/update2/crx"
    # Homepage URL
    reg add "HKLM\Software\Policies\Google\Chrome\RestoreOnStartupURLs" /v "1" /t REG_SZ /d "https://www.tcanationals.com/contest-start" /f
    # Certificate auth
    reg add "HKLM\Software\Policies\Google\Chrome\AutoSelectCertificateForUrls" /v "1" /t REG_SZ /d "temp" /f # create reg key if doesn't exist
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\AutoSelectCertificateForUrls" -Name "1" -Value '{"pattern":"https://*.tcalocal.com","filter":{"ISSUER":{"CN":"Technical Computer Applications"},"SUBJECT":{"OU:"User Auth"}}' # Set actual value
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\AutoSelectCertificateForUrls" -Name "2" -Value '{"pattern":"https://*.tcanationals.com","filter":{"ISSUER":{"CN":"Technical Computer Applications"},"SUBJECT":{"OU:"User Auth"}}'
    # Policy settings
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ShowCastIconInToolbar" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "HomepageIsNewTabPage" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "PasswordManagerEnabled" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "UserFeedbackAllowed" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "NTPCustomBackgroundEnabled" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "BrowserSignin" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "DnsOverHttpsMode" -Value "off"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "SyncDisabled" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "AutoFillEnabled" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ForceGoogleSafeSearch" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ShowHomeButton" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "DeveloperToolsAvailability" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ProfilePickerOnStartupAvailability" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "ShowFullUrlsInAddressBar" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "BrowserAddPersonEnabled" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "BrowserGuestModeEnabled" -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "EnableCommonNameFallbackForLocalAnchors" -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "IncognitoModeAvailability" -Value 1 # incognito disabled
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "RestoreOnStartup" -Value 4 # open homepage
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "HomepageLocation" -Value "https://www.tcanationals.com/contest-start"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "NewTabPageLocation" -Value "about:blank"

    # Customize default user preferences
    reg load "HKU\temp" c:\users\default\ntuser.dat
    # Disable most used apps from appearing in the start menu
    reg add "HKU\temp\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_TrackProgs" /t REG_DWORD /d 0 /f
    # Show file extensions
    reg add "HKU\temp\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f
    # Show all taskbar notifications
    reg add "HKU\temp\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "EnableAutoTray" /t REG_DWORD /d 0 /f
    reg unload "hku\temp"

    # Add desktop shortcuts
    Create-Shortcut -Name "Access" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\MSACCESS.exe"
    Create-Shortcut -Name "Excel" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\EXCEL.exe"
    Create-Shortcut -Name "Google Chrome" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    Create-Shortcut -Name "Outlook" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.exe"
    Create-Shortcut -Name "PowerPoint" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\POWERPNT.exe"
    Create-Shortcut -Name "Power BI Desktop" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Power BI Desktop\bin\PBIDesktop.exe"
    Create-Shortcut -Name "Publisher" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\MSPUB.exe"
    Create-Shortcut -Name "Visio" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\VISIO.exe"
    Create-Shortcut -Name "Word" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.exe"
    Create-Shortcut -Name "Visual Studio Code" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    Create-Shortcut -Name "VMware Player" -shortcuts "CommonDesktop" -TargetPath "${Env:ProgramFiles(x86)}\VMware\VMware Player\vmplayer.exe"
    Create-Shortcut -Name "Compass" -shortcuts "CommonDesktop" -TargetPath "C:\Certiport\Compass\CompassPreLoader.exe"
    Create-Shortcut -Name "Tableau" -shortcuts "CommonDesktop" -TargetPath "$env:ProgramFiles\Tableau\Tableau 2022.1\bin\tableau.exe"
    Create-Shortcut -Name "Disconnect" -shortcuts "CommonDesktop" -TargetPath "$Env:WinDir\System32\tsdiscon.exe" -IconLocation "$Env:WinDir\System32\shell32.dll,131"

    # Add start menu shortcuts
    Create-Shortcut -Name "Self-Support" -shortcuts "CommonStartMenu" -TargetPath "$env:ProgramFiles\Immidio\Flex Profiles\Flex+ Self-Support.exe"
    Create-Shortcut -Name "Tableau" -shortcuts "CommonStartMenu" -TargetPath "$env:ProgramFiles\Tableau\Tableau 2022.1\bin\tableau.exe"
    Create-Shortcut -Name "Performance Monitor" -shortcuts "CommonStartMenu" -TargetPath "$env:ProgramFiles\VMware\VMware View\Agent\Horizon Performance Tracker\VMware.Horizon.PerformanceTracker.exe"
    Create-Shortcut -Name "Zoom" -shortcuts "CommonStartMenu" -TargetPath "${Env:ProgramFiles(x86)}\ZoomVDI\bin\Zoom.exe"

    # Update local group policies
    $MachineGPDir = "$env:windir\system32\GroupPolicy\Machine\registry.pol"
    $UserGPDir = "$env:windir\system32\GroupPolicy\User\registry.pol"

    # Disable Wallpaper setting
    Remove-PolicyFileEntry -Path $UserGPDir -Key 'Software\Microsoft\Windows\CurrentVersion\Policies\System' -ValueName 'WallPaper'
    # Set file associations
    Set-PolicyFileEntry -Path $MachineGPDir -Key 'Software\Policies\Microsoft\Windows\System' -ValueName 'DefaultAssociationsConfiguration' -Data "$PackerConfig\defaultassociations.xml"
    # Disable taskbar icons
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Policies\Microsoft\Windows\Explorer' -ValueName 'DisableNotificationCenter' -Data '1' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ValueName 'HideSCANetwork' -Data '1' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -ValueName 'HideSCAHealth' -Data '1' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Microsoft\Windows\CurrentVersion\Search' -ValueName 'SearchboxTaskbarMode' -Data '0' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ValueName 'ShowTaskViewButton' -Data '0' -Type 'DWORD'
    Set-PolicyFileEntry -Path $MachineGPDir -Key 'Software\Policies\Microsoft\Windows Defender Security Center\Systray' -ValueName 'HideSystray' -Data '1' -Type 'DWORD'
    # Office policies
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Policies\Microsoft\Office\16.0\FirstRun' -ValueName 'disablemovie' -Data '1' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Policies\Microsoft\Office\16.0\FirstRun' -ValueName 'bootedrtm' -Data '1' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Policies\Microsoft\Office\16.0\Common\Signin' -ValueName 'signinoptions' -Data '3' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Policies\Microsoft\Office\16.0\Common\General' -ValueName 'skydrivesigninoption' -Data '0' -Type 'DWORD'
    Set-PolicyFileEntry -Path $UserGPDir -Key 'Software\Policies\Microsoft\Office\16.0\Common' -ValueName 'linkedin' -Data '0' -Type 'DWORD'

    # Setup task to delete Administrator user profile on reboot (task will enable WinRM once finished)
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

# Reboot
shutdown /t 10 /r /f /c \"Packer Reboot\" /d p:4:1

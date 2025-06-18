$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

Import-Module TCA -DisableNameChecking

# Install the base system apps (before Horizon)
#$VmwareFilename = "VMware-player-17.5.2-23775571.exe"
$VmwareFilename = "VMware-workstation-full-17.6.3-24583834.exe"
TCA-DownloadFile "$VmwareFilename"
Start-Process -Wait -FilePath "$PackerDownloads\$VmwareFilename" -ArgumentList "/s /v/qn EULAS_AGREED=1 AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0 REBOOT=ReallySuppress"
Remove-Item -Path "$PackerDownloads\$VmwareFilename"

# Setup default user profile VMware preferences
$vmwDefaultPath = "C:\Users\Default\AppData\Roaming\VMware"
if (-Not (Test-Path $vmwDefaultPath)) {
    New-Item $vmwDefaultPath -ItemType Directory
}
$vmwPref = @"
.encoding = "windows-1252"
pref.keyboardAndMouse.vmHotKey.enabled = "FALSE"
pref.keyboardAndMouse.vmHotKey.count = "0"
pref.vmplayer.firstRunDismissedVersion = "17.5.2"
pref.componentDownloadPermission.epoch = ""
pref.componentDownloadPermission = "deny"
hint.vmx.nestedVM = "FALSE"
hints.hideAll = "TRUE"
hint.cui.toolsInfoBar.suppressible = "FALSE"
pref.mruVM0.filename = "$PackerPublic\TroubleshootingVM\TroubleshootingVM.vmx"
pref.mruVM0.displayName = "Troubleshooting VM (ShortCircuit)"
pref.mruVM0.index = "0"
pref.mruVM1.filename = "$PackerPublic\WhiteoutVM\WhiteoutVM.vmx"
pref.mruVM1.displayName = "Troubleshooting VM (Whiteout)"
pref.mruVM1.index = "1"
"@
Set-Content "$vmwDefaultPath\preferences.ini" $vmwPref

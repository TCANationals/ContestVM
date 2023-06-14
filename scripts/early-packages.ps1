# Install WSL 2
choco install wsl2 -y --params "/Version:2 /Retry:true"

# Install the base system apps (before Horizon)
choco install vmware-workstation-player --no-progress -y --override=1 --installargs="'/s /v/qn EULAS_AGREED=1 AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0 ADDLOCAL=ALL REMOVE=Keyboard REBOOT=ReallySuppress'"
#choco install vmwareworkstation -y --override=1 --installargs="'/s /v/qn EULAS_AGREED=1 AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0 ADDLOCAL=ALL REMOVE=Keyboard REBOOT=ReallySuppress'"

# Setup default user profile VMware preferences
$vmwDefaultPath = "C:\Users\Default\AppData\Roaming\VMware"
if (-Not (Test-Path $vmwDefaultPath)) {
    New-Item $vmwDefaultPath -ItemType Directory
}
$vmwPref = @"
.encoding = "windows-1252"
pref.keyboardAndMouse.vmHotKey.enabled = "FALSE"
pref.keyboardAndMouse.vmHotKey.count = "0"
pref.vmplayer.firstRunDismissedVersion = "17.0.2"
hint.vmx.nestedVM = "FALSE"
hints.hideAll = "TRUE"
hint.cui.toolsInfoBar.suppressible = "FALSE"
pref.mruVM0.filename = "$PackerPublic\TroubleshootingVM\TroubleshootingVM.vmx"
pref.mruVM0.displayName = "Troubleshooting VM"
pref.mruVM0.index = "0"
"@
Set-Content "$vmwDefaultPath\preferences.ini" $vmwPref

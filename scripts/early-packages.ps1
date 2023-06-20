. C:\Packer\Scripts\tca-env.ps1

# Install WSL 2
try {
    Choco-Install -PackageName wsl2 -RetryCount 3 -ArgumentList "--ignore-package-exit-codes", "--params", '"/Version:2 /Retry:true"'
} catch {
    Write-Host "WSL install failed, ignoring..."
}

# Install the base system apps (before Horizon)
Choco-Install -PackageName vmware-workstation-player -ArgumentList "--override=1", "--installargs=`"'/s /v/qn EULAS_AGREED=1 AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0 ADDLOCAL=ALL REMOVE=Keyboard REBOOT=ReallySuppress'`""
#Choco-Install -PackageName vmwareworkstation --override=1 --installargs="'/s /v/qn EULAS_AGREED=1 AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0 ADDLOCAL=ALL REMOVE=Keyboard REBOOT=ReallySuppress'"

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
pref.mruVM0.displayName = "Troubleshooting VM (ShortCircuit)"
pref.mruVM0.index = "0"
pref.mruVM1.filename = "$PackerPublic\WhiteoutVM\WhiteoutVM.vmx"
pref.mruVM1.displayName = "Troubleshooting VM (Whiteout)"
pref.mruVM1.index = "1"
"@
Set-Content "$vmwDefaultPath\preferences.ini" $vmwPref

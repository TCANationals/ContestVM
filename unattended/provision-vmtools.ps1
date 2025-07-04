Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

$systemVendor = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -Property Vendor).Vendor
if ($systemVendor -eq 'VMware, Inc.') {
    Write-Output 'Installing VMware Tools...'
    # silent install without rebooting.
    if (Test-Path E:\setup64.exe) {
        E:\setup64.exe /s /v '/qn reboot=r' `
            | Out-String -Stream
    } else {
        # newest releases of vmware tools only have single installer
        E:\setup.exe /S /v '/qn reboot=r' `
            | Out-String -Stream
    }
}

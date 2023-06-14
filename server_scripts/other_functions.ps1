Import-Module ADDSDeployment
Import-Module ADFS


# Setup AD
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "tcalocal.com" `
-DomainNetbiosName "TCA" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

# Add KDS key to AD
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)

Install-AdfsFarm `
-CertificateThumbprint:"145DD3E4F539FF5686DC14867FCF220544512526" `
-FederationServiceDisplayName:"TCA 2023" `
-FederationServiceName:"TCA-AD1.tcalocal.com" `
-GroupServiceAccountIdentifier:"TCA\adfs_svc_acct`$"

# Setup central policy store
if ( -not (Test-Path "C:\Windows\SYSVOL\domain\Policies\PolicyDefinitions")){
    robocopy /xc /xn /xo "C:\Windows\PolicyDefinitions" "C:\Windows\SYSVOL\domain\Policies\PolicyDefinitions" /R:5 /W:1 /E
    robocopy /xc /xn /xo ".\policies" "C:\Windows\SYSVOL\domain\Policies\PolicyDefinitions" /R:5 /W:1 /E
} else {
    Write-Host "Central store already exists" -ForegroundColor Green
}

# LSC IP range
TCA-DownloadFile "LCS_91050.msi"
New-ADGroup -Name "LanSchool Teachers" -GroupScope Global -DisplayName "LanSchool Teachers" -Path "CN=Users,DC=tcalocal,DC=Com"
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\LanSchool" /v IPSubnet /t REG_SZ /d "172.16.0.0" /f
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\LanSchool" /v IPSubnetMask /t REG_SZ /d "255.255.255.0" /f

# Setup LAPS
Update-LapsADSchema
Set-LapsADComputerSelfPermission -Identity "Computers"
Set-LapsADComputerSelfPermission -Identity "HorizonVMs"

# Set AWS credentials
$awsArgs = @{
    AccessKey = (Read-Host 'AWS Access Key' -AsSecureString)
    SecretKey = (Read-Host 'AWS Secret Key' -AsSecureString)
}
Set-AWSCredential -AccessKey ([System.Net.NetworkCredential]::new("", $awsArgs.AccessKey).Password) -SecretKey ([System.Net.NetworkCredential]::new("", $awsArgs.SecretKey).Password) -StoreAs default
Initialize-AWSDefaultConfiguration -ProfileName default -Region us-east-1

# setup shared folders
# get domain admin & domain user group IDs
$domainAdmins = (Get-ADGroup -Identity "Domain Admins").SID
$authenticatedUsers = New-Object -TypeName "System.Security.Principal.SecurityIdentifier" -ArgumentList @([System.Security.Principal.WellKnownSidType]::AuthenticatedUserSid, $null)
$systemUser = New-Object -TypeName "System.Security.Principal.SecurityIdentifier" -ArgumentList @([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
$creatorOwnerUser = New-Object -TypeName "System.Security.Principal.SecurityIdentifier" -ArgumentList @([System.Security.Principal.WellKnownSidType]::CreatorOwnerSid, $null)

# Setup root share directory & ensure only domain admins have access
force-mkdir D:\Shares
$acl = Get-Acl D:\Shares
$acl.SetOwner($domainAdmins)
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $domainAdmins, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
$acl.SetAccessRuleProtection($True, $False)
Set-Acl D:\Shares $acl

# Setup public share and give everyone read-only access
force-mkdir D:\Shares\Public\_Judges
New-SmbShare -Name Public -Path "D:\Shares\Public" -FullAccess "Everyone"
$acl = Get-Acl D:\Shares\Public
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $authenticatedUsers, 'Read, ReadAndExecute, ListDirectory', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
Set-Acl D:\Shares\Public $acl

# Judge specific folder
$acl = Get-Acl D:\Shares\Public\_Judges
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $domainAdmins, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
$acl.SetAccessRuleProtection($True, $False)
Set-Acl D:\Shares\Public\_Judges $acl

# DEM Config share
force-mkdir D:\Shares\DEM
New-SmbShare -Name DEM$ -Path "D:\Shares\DEM" -FullAccess "Everyone"
$acl = Get-Acl D:\Shares\DEM
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $authenticatedUsers, 'Read, ReadAndExecute, ListDirectory', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
Set-Acl D:\Shares\DEM $acl

# Users share, permission for users to create their own directory (from DEM on login)
force-mkdir D:\Shares\Users
New-SmbShare -Name Users$ -Path "D:\Shares\Users" -FullAccess "Everyone"
$acl = Get-Acl D:\Shares\Users
# All auth users can list directory and create new folders
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $authenticatedUsers, 'ReadData, AppendData, ExecuteFile, Synchronize', 'None', 'None', 'Allow'
)))
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $creatorOwnerUser, 'Modify, Synchronize', 'ContainerInherit, ObjectInherit', 'InheritOnly', 'Allow'
)))
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $systemUser, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
Set-Acl D:\Shares\Users $acl

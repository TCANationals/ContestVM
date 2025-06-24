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

# MANUAL: Update password group policy to allow unsecure passwords
# MANUAL: Import TCA group policy from below
# MANUAL: Update TCA group policy
#     Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies > Certificate Services Client - Certificate Enrollment Policy
#     Under Certificate Enrollment Policy List, remove the Active Directory Enrollment Policy. Then re-add it and set it as the default.
#     GUID changes with each AD install, so this resets it

# MANUAL: Setup CA & User template
#     https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/jj129701(v=ws.11)

# Orientation
# https://docs.google.com/presentation/d/1SUUMAX8E7nMuTkbZK0JPm9S8mZ23-NCoOckCA_Jdaxk/edit

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
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\LanSchool" /v IPSubnet /t REG_SZ /d "192.168.1.0" /f
& reg add "HKEY_LOCAL_MACHINE\SOFTWARE\LanSchool" /v IPSubnetMask /t REG_SZ /d "255.255.255.0" /f

# Download teacher file
TCA-DownloadFile "Teacher_91050.msi"

# Setup LAPS
Update-LapsADSchema
Set-LapsADComputerSelfPermission -Identity "Computers"
Set-LapsADComputerSelfPermission -Identity "HorizonVMs"

# setup shared folders
# get domain admin & domain user group IDs
$domainAdmins = (Get-ADGroup -Identity "Domain Admins").SID
$authenticatedUsers = New-Object -TypeName "System.Security.Principal.SecurityIdentifier" -ArgumentList @([System.Security.Principal.WellKnownSidType]::AuthenticatedUserSid, $null)
$systemUser = New-Object -TypeName "System.Security.Principal.SecurityIdentifier" -ArgumentList @([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
$creatorOwnerUser = New-Object -TypeName "System.Security.Principal.SecurityIdentifier" -ArgumentList @([System.Security.Principal.WellKnownSidType]::CreatorOwnerSid, $null)

# Setup root share directory & ensure only domain admins have access
force-mkdir F:\Shares
$acl = Get-Acl F:\Shares
$acl.SetOwner($domainAdmins)
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $domainAdmins, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
$acl.SetAccessRuleProtection($True, $False)
Set-Acl F:\Shares $acl

# Setup public share and give everyone read-only access
force-mkdir F:\Shares\Public\_Judges
New-SmbShare -Name Public -Path "F:\Shares\Public" -ChangeAccess "Everyone" -FullAccess = 'TCA\Domain Admins'
$acl = Get-Acl F:\Shares\Public
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $authenticatedUsers, 'Read, ReadAndExecute, ListDirectory', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
Set-Acl F:\Shares\Public $acl

# Judge specific folder
$acl = Get-Acl F:\Shares\Public\_Judges
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $domainAdmins, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
$acl.SetAccessRuleProtection($True, $False)
Set-Acl F:\Shares\Public\_Judges $acl

# DEM Config share
force-mkdir F:\Shares\DEM
New-SmbShare -Name DEM$ -Path "F:\Shares\DEM" -ChangeAccess "Everyone" -FullAccess = 'TCA\Domain Admins'
$acl = Get-Acl F:\Shares\DEM
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $authenticatedUsers, 'Read, ReadAndExecute, ListDirectory', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
)))
Set-Acl F:\Shares\DEM $acl

# Users share, permission for users to create their own directory (from DEM on login)
force-mkdir F:\Shares\Users
New-SmbShare -Name Users$ -Path "F:\Shares\Users" -ChangeAccess "Everyone" -FullAccess = 'TCA\Domain Admins'
$acl = Get-Acl F:\Shares\Users
# All auth users can list directory (fix issue with Office)
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
    $authenticatedUsers, 'ListDirectory, ReadData, ExecuteFile, Synchronize, ReadExtendedAttributes, ReadAttributes, ReadPermissions, Read', 'None', 'None', 'Allow'
)))
# No other permissions here, will manually create directories for users in add_ad_users.ps1
# $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
#     $creatorOwnerUser, 'Modify, Synchronize', 'ContainerInherit, ObjectInherit', 'InheritOnly', 'Allow'
# )))
# $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
#     $systemUser, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
# )))
Set-Acl F:\Shares\Users $acl

# set ACLs
#Set-HomeFolderACL -Path 'F:\Shares\Users'

# Setup exchange certificate
# Run on AD server with Exchange tools installed
Get-Command -Module PSPKI
. 'C:\Program Files\Microsoft\Exchange Server\V15\bin\RemoteExchange.ps1'
Connect-ExchangeServer -auto

$TempFile = New-TemporaryFile

$exchrequest = New-ExchangeCertificate -PrivateKeyExportable $False -GenerateRequest -FriendlyName "TCA-EXCH1" -SubjectName "C=US,CN=TCA-EXCH1.tcalocal.com" -DomainName TCA-EXCH1.tcalocal.com,TCA-EXCH1
$exchrequest | Out-File -FilePath $TempFile

$localCa = Connect-CertificationAuthority
$issuedCert = Submit-CertificateRequest -Path $TempFile -CA $localCa -Attribute "CertificateTemplate:WebServer"

$exchCert = Import-ExchangeCertificate -FileData $issuedCert.Certificate.RawData
Enable-ExchangeCertificate -Thumbprint $issuedCert.Certificate.Thumbprint -Services POP,IMAP,IIS,SMTP -Force

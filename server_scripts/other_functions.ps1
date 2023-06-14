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


# Set AWS credentials
$awsArgs = @{
    AccessKey = (Read-Host 'AWS Access Key' -AsSecureString)
    SecretKey = (Read-Host 'AWS Secret Key' -AsSecureString)
}
Set-AWSCredential -AccessKey $awsArgs.AccessKey -SecretKey $awsArgs.SecretKey -StoreAs default
Initialize-AWSDefaultConfiguration -ProfileName default -Region us-east-1

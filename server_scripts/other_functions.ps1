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
} else {
    Write-Host "Central store already exists" -ForegroundColor Green
}

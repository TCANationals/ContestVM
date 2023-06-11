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


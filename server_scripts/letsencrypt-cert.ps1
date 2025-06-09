#requires -Version 5

# https://poshac.me/

$email = "info@tcanationals.com"
$dnsName = "horizon.tcanationals.com"

$uag = "192.168.1.5"

$user = 'admin'
Write-Host "Please enter the UAG admin password."
$pass = Read-Host -AsSecureString "UAG Admin password"
$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
$creds = "$($user):$($pass)"
$credsBytes = [System.Text.Encoding]::UTF8.GetBytes($creds)
$encodedCreds = [Convert]::ToBase64String($credsBytes)

$psMod = "Posh-ACME"
if (!(Get-InstalledModule -Name $psMod)) {
    # Install the Posh-ACME module 
    Install-Module -Name $psMod -Scope CurrentUser -Force
}

Set-PAServer LE_PROD


New-PACertificate $dnsName -AcceptTOS -Contact $email -Verbose -Force
$newCert = Get-PACertificate

# Convert private key to one-liner
$privKey = [IO.File]::ReadAllText($newCert.KeyFile)
$privKeyReplace = $privKey.Replace("`n",'\n')

# Convert SSL certificate to one-liner 
$cert = [IO.File]::ReadAllText($newCert.FullChainFile)
$certReplace = $cert.Replace("`n",'\n')

# Create JSON body
$json = '{"privateKeyPem":"' + $privKeyReplace + '","certChainPem":"' + $certReplace + '"}'

# Define API parameters
$params = @{
    Headers     = @{ 'Authorization' = "Basic $encodedCreds" }
    Method      = 'PUT'
    Body        = $json
    ContentType = 'application/json'
}


# Define the URI
$Uri = "https://" + $uag + ':9443/rest/v1/config/certs/ssl'
    
# Display UAG
Write-Host "UAG is: " $uag


# Connect to each UAG and replace SSL certificate and private key
Invoke-RestMethod -SkipCertificateCheck $uri @params

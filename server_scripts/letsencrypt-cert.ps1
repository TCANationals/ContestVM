#requires -Version 5
#requires -PSEdition Desktop

# https://poshac.me/docs/v4/Plugins/Cloudflare/

$email = "info@tcanationals.com"
$dnsName = "horizon.tcanationals.com"

$uag = "172.16.0.4"

$user = 'admin'
Write-Host "Please enter the UAG admin password."
$pass = Read-Host -AsSecureString "UAG Admin password"
$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
$creds = "$($user):$($pass)"


$pArgs = @{
    CFToken = (Read-Host 'Cloudflare API Token' -AsSecureString)
}

$psMod = "Posh-ACME"
if (!(Get-InstalledModule -Name $psMod)) {
    # Install the Posh-ACME module 
    Install-Module -Name $psMod -Scope CurrentUser -Force
}

Set-PAServer LE_PROD


New-PACertificate $dnsName -AcceptTOS -DnsPlugin Cloudflare -PluginArgs $pArgs -Contact $email -Verbose -Force
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

class TrustAllCertsPolicy : System.Net.ICertificatePolicy {
    [bool] CheckValidationResult([System.Net.ServicePoint] $a,
                                 [System.Security.Cryptography.X509Certificates.X509Certificate] $b,
                                 [System.Net.WebRequest] $c,
                                 [int] $d) {
        return $true
    }
}
[System.Net.ServicePointManager]::CertificatePolicy = [TrustAllCertsPolicy]::new()

# Connect to each UAG and replace SSL certificate and private key
Invoke-RestMethod $uri @params 

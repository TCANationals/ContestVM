. C:\Packer\Scripts\tca-env.ps1

$ChocolateyServerInstall = "https://chocolatey.org/install.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString($ChocolateyServerInstall))

# Base chocolatey tools
Choco-Install -PackageName chocolatey-core.extension
Choco-Install -PackageName chocolatey-windowsupdate.extension

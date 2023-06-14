. C:\Packer\Scripts\tca-env.ps1

$ChocolateyServerInstall = "https://chocolatey.org/install.ps1"
#$CholateyServer = "http://<your_server>/chocolatey"
#choco install $APP1 -s $CholateyServer -y


Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString($ChocolateyServerInstall))

# Base chocolatey tools
choco install chocolatey-core.extension -y
choco install chocolatey-windowsupdate.extension -y

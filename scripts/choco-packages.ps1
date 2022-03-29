. C:\Packer\Scripts\tca-env.ps1

# Install the core system apps
choco install laps -y --params='"/ALL"'
choco install sysinternals -y
choco install vlc -y
choco install adobereader -y
choco install winrar -y
choco install notepadplusplus -y
choco install googlechrome -y
choco install microsoft-windows-terminal -y
choco install microsoft-office-deployment -y --params="'/64bit /DisableUpdate:TRUE /Product:ProPlus2021Volume,VisioPro2021Volume,ProjectPro2021Volume /Exclude:OneDrive,Lync,Groove,Teams'"
choco install powerbi -y
choco install tableau-desktop -y
choco install vscode -y
choco install speedtest -y

# Setup bginfo on logon
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "BGInfo" -Value '"C:\ProgramData\chocolatey\bin\Bginfo64.exe" "$PackerConfig\logon.bgi" /timer:0 /silent /nolicprompt' -ea SilentlyContinue -wa SilentlyContinue

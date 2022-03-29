<#
  .SYNOPSIS
	TCA-specific functions
  .DESCRIPTION
  Provides TCA functions, mostly ways to download private content we can't publish publicly
#>

# Placeholder Environment script for common variable definition.
$ErrorActionPreference = 'Continue'

. C:\Packer\Scripts\windows-env.ps1

$TCAPrivateUrl = "${private_url}"

# Function to download the private packages we need
Function TCA-DownloadFile {
  param (
    [string]$file
  )

  Download-File "$TCAPrivateUrl/$file" "$PackerDownloads\$file"
}

Function Get-GithubLatestRelease {
  param (
    [string]$repo,
    [string]$match,
    [string]$file
  )

  $githubLatestReleases = "https://api.github.com/repos/$repo/releases/latest"
  $githubLatestReleasesJson = ((Invoke-WebRequest -Uri $gitHubLatestReleases -UseBasicParsing) | ConvertFrom-Json).assets.browser_download_url
  $Uri = ($githubLatestReleasesJson | Select-String "$match").ToString()

  Download-File "$Uri" "$PackerDownloads\$file"
}

Function Create-NewLocalAdmin {
  [CmdletBinding()]
  param (
      [string] $NewLocalAdmin,
      [securestring] $Password
  )
  begin {
  }
  process {
      $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
      $existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $NewLocalAdmin }

      if ($existing -eq $null) {

        Write-Host "Creating new local user $NewLocalAdmin."
        & NET USER $NewLocalAdmin $Password /add /y /expires:never
        Write-Host "Adding local user $NewLocalAdmin to Administrators."
        & NET LOCALGROUP Administrators $NewLocalAdmin /add

        # Hide new account on login screen
        Hide-LocalUserLogin $NewLocalAdmin
        # Setup new profile so this account can be used
        Create-LocalUserProfile $NewLocalAdmin
      } else {
        Write-Host "Setting password for existing local user $NewLocalAdmin."
        $existing.SetPassword($Password)
      }

      Write-Host "Ensuring password for $NewLocalAdmin never expires."
      & WMIC USERACCOUNT WHERE "Name='$NewLocalAdmin'" SET PasswordExpires=FALSE
  }
  end {
  }
}

Function Hide-LocalUserLogin {
  [CmdletBinding()]
  param (
      [string] $username
  )
  begin {
  }
  process {
    # Hide new account on login screen
    Write-Host "Hiding user from login screen: $username"
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ea SilentlyContinue -wa SilentlyContinue
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts" -ea SilentlyContinue -wa SilentlyContinue 
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -ea SilentlyContinue -wa SilentlyContinue
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -Name $username -PropertyType DWord -Value 0 -ea SilentlyContinue -wa SilentlyContinue
  }
  end {
  }
}

Function Create-LocalUserProfile {
  param (
    [Parameter(Mandatory)]
    [string] $username
  )
  $methodName = 'UserEnvCP'
  $script:nativeMethods = @();

  Register-NativeMethod "userenv.dll" "int CreateProfile([MarshalAs(UnmanagedType.LPWStr)] string pszUserSid,`
    [MarshalAs(UnmanagedType.LPWStr)] string pszUserName,`
    [Out][MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszProfilePath, uint cchProfilePath)";

  Add-NativeMethods -typeName $MethodName;

  $localUser = New-Object System.Security.Principal.NTAccount("$username");
  $userSID = $localUser.Translate([System.Security.Principal.SecurityIdentifier]);
  $sb = new-object System.Text.StringBuilder(260);
  $pathLen = $sb.Capacity;

  Write-Verbose "Creating user profile for $username";
  try
  {
    [UserEnvCP]::CreateProfile($userSID.Value, $username, $sb, $pathLen) | Out-Null;
  }
  catch
  {
    Write-Error $_.Exception.Message;
    break;
  }
}

Function Get-RandomPassword {
  param (
      [Parameter(Mandatory)]
      [int] $length
  )
  # Only want alphanumeric here
  $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()
  $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
  $bytes = New-Object byte[]($length)

  $rng.GetBytes($bytes)

  $result = New-Object char[]($length)

  for ($i = 0 ; $i -lt $length ; $i++) {
    $result[$i] = $charSet[$bytes[$i]%$charSet.Length]
  }

  return (-join $result)
}

Function Get-Tree($Path,$Include='*') { 
  @(Get-Item $Path -Include $Include -Force) + 
      (Get-ChildItem $Path -Recurse -Include $Include -Force) | 
      sort pspath -Descending -unique
} 

Function Remove-Tree($Path,$Include='*') { 
  Get-Tree $Path $Include | Remove-Item -force -recurse
}

Function Register-NativeMethod
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$dll,
 
        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]
        $methodSignature
    )
 
    $script:nativeMethods += [PSCustomObject]@{ Dll = $dll; Signature = $methodSignature; }
}

Function Add-NativeMethods
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param($typeName = 'NativeMethods')
 
    $nativeMethodsCode = $script:nativeMethods | ForEach-Object { "
        [DllImport(`"$($_.Dll)`")]
        public static extern $($_.Signature);
    " }
 
    Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
        public static class $typeName {
            $nativeMethodsCode
        }
"@
}

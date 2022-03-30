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

Function Set-RegistryValueForAllUsers {
	<#
    .SYNOPSIS
        This function uses Active Setup to create a "seeder" key which creates or modifies a user-based registry value
        for all users on a computer. If the key path doesn't exist to the value, it will automatically create the key and add the value.
    .EXAMPLE
        PS> Set-RegistryValueForAllUsers -RegistryInstance @{'Name' = 'Setting'; 'Type' = 'String'; 'Value' = 'someval'; 'Path' = 'SOFTWARE\Microsoft\Windows\Something'}

        This example would modify the string registry value 'Type' in the path 'SOFTWARE\Microsoft\Windows\Something' to 'someval'
        for every user registry hive.
    .PARAMETER RegistryInstance
        A hash table containing key names of 'Name' designating the registry value name, 'Type' to designate the type
        of registry value which can be 'String,Binary,Dword,ExpandString or MultiString', 'Value' which is the value itself of the
        registry value and 'Path' designating the parent registry key the registry value is in.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]]$RegistryInstance
    )
    try {
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null

        ## Change the registry values for the currently logged on user. Each logged on user SID is under HKEY_USERS
        $LoggedOnSids = (Get-ChildItem HKU: | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+' }).PSChildName
        Write-Verbose "Found $($LoggedOnSids.Count) logged on user SIDs"
        foreach ($sid in $LoggedOnSids) {
            Write-Verbose -Message "Loading the user registry hive for the logged on SID $sid"
            foreach ($instance in $RegistryInstance) {
                ## Create the key path if it doesn't exist
                New-Item -Path "HKU:\$sid\$($instance.Path | Split-Path -Parent)" -Name ($instance.Path | Split-Path -Leaf) -Force | Out-Null
                ## Create (or modify) the value specified in the param
                Set-ItemProperty -Path "HKU:\$sid\$($instance.Path)" -Name $instance.Name -Value $instance.Value -Type $instance.Type -Force
            }
        }

        ## Create the Active Setup registry key so that the reg add cmd will get ran for each user
        ## logging into the machine.
        ## http://www.itninja.com/blog/view/an-active-setup-primer
        Write-Verbose "Setting Active Setup registry value to apply to all other users"
        foreach ($instance in $RegistryInstance) {
            ## Generate a unique value (usually a GUID) to use for Active Setup
            $Guid = [guid]::NewGuid().Guid
            $ActiveSetupRegParentPath = 'HKLM:\Software\Microsoft\Active Setup\Installed Components'
            ## Create the GUID registry key under the Active Setup key
            New-Item -Path $ActiveSetupRegParentPath -Name $Guid -Force | Out-Null
            $ActiveSetupRegPath = "HKLM:\Software\Microsoft\Active Setup\Installed Components\$Guid"
            Write-Verbose "Using registry path '$ActiveSetupRegPath'"

            ## Convert the registry value type to one that reg.exe can understand.  This will be the
            ## type of value that's created for the value we want to set for all users
            switch ($instance.Type) {
                'String' {
                    $RegValueType = 'REG_SZ'
                }
                'Dword' {
                    $RegValueType = 'REG_DWORD'
                }
                'Binary' {
                    $RegValueType = 'REG_BINARY'
                }
                'ExpandString' {
                    $RegValueType = 'REG_EXPAND_SZ'
                }
                'MultiString' {
                    $RegValueType = 'REG_MULTI_SZ'
                }
                default {
                    throw "Registry type '$($instance.Type)' not recognized"
                }
            }

            ## Build the registry value to use for Active Setup which is the command to create the registry value in all user hives
            $ActiveSetupValue = 'reg add "{0}" /v {1} /t {2} /d {3} /f' -f "HKCU\$($instance.Path)", $instance.Name, $RegValueType, $instance.Value
            Write-Verbose -Message "Active setup value is '$ActiveSetupValue'"
            ## Create the necessary Active Setup registry values
            Set-ItemProperty -Path $ActiveSetupRegPath -Name '(Default)' -Value 'Registry Change - Add' -Force
            Set-ItemProperty -Path $ActiveSetupRegPath -Name 'Version' -Value '1' -Force
            Set-ItemProperty -Path $ActiveSetupRegPath -Name 'StubPath' -Value $ActiveSetupValue -Force
        }
    } catch {
        Write-Warning -Message $_.Exception.Message
    }
}

Function Remove-RegistryValueForAllUsers {
	<#
    .SYNOPSIS
        This function uses Active Setup to create a "seeder" key which creates or modifies a user-based registry value
        for all users on a computer. If the key path doesn't exist to the value, it will automatically create the key and add the value.
    .EXAMPLE
        PS> Set-RegistryValueForAllUsers -RegistryInstance @{'Name' = 'Setting'; 'Type' = 'String'; 'Value' = 'someval'; 'Path' = 'SOFTWARE\Microsoft\Windows\Something'}

        This example would modify the string registry value 'Type' in the path 'SOFTWARE\Microsoft\Windows\Something' to 'someval'
        for every user registry hive.
    .PARAMETER RegistryInstance
        A hash table containing key names of 'Name' designating the registry value name, 'Type' to designate the type
        of registry value which can be 'String,Binary,Dword,ExpandString or MultiString', 'Value' which is the value itself of the
        registry value and 'Path' designating the parent registry key the registry value is in.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]]$RegistryInstance
    )
    try {
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null

        ## Change the registry values for the currently logged on user. Each logged on user SID is under HKEY_USERS
        $LoggedOnSids = (Get-ChildItem HKU: | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+' }).PSChildName
        Write-Verbose "Found $($LoggedOnSids.Count) logged on user SIDs"
        foreach ($sid in $LoggedOnSids) {
            Write-Verbose -Message "Loading the user registry hive for the logged on SID $sid"
            foreach ($instance in $RegistryInstance) {
                ## Create the key path if it doesn't exist
                New-Item -Path "HKU:\$sid\$($instance.Path | Split-Path -Parent)" -Name ($instance.Path | Split-Path -Leaf) -Force | Out-Null
                ## Create (or modify) the value specified in the param
                Remove-ItemProperty -Path "HKU:\$sid\$($instance.Path)"  -Name $instance.Name -Force -ea SilentlyContinue -wa SilentlyContinue
            }
        }

        ## Create the Active Setup registry key so that the reg add cmd will get ran for each user
        ## logging into the machine.
        ## http://www.itninja.com/blog/view/an-active-setup-primer
        Write-Verbose "Setting Active Setup registry value to apply to all other users"
        foreach ($instance in $RegistryInstance) {
            ## Generate a unique value (usually a GUID) to use for Active Setup
            $Guid = [guid]::NewGuid().Guid
            $ActiveSetupRegParentPath = 'HKLM:\Software\Microsoft\Active Setup\Installed Components'
            ## Create the GUID registry key under the Active Setup key
            New-Item -Path $ActiveSetupRegParentPath -Name $Guid -Force | Out-Null
            $ActiveSetupRegPath = "HKLM:\Software\Microsoft\Active Setup\Installed Components\$Guid"
            Write-Verbose "Using registry path '$ActiveSetupRegPath'"

            ## Build the registry value to use for Active Setup which is the command to create the registry value in all user hives
            $ActiveSetupValue = 'reg delete "{0}" /v {1} /f' -f "HKCU\$($instance.Path)", $instance.Name
            Write-Verbose -Message "Active setup value is '$ActiveSetupValue'"
            ## Create the necessary Active Setup registry values
            Set-ItemProperty -Path $ActiveSetupRegPath -Name '(Default)' -Value 'Registry Change - Remove' -Force
            Set-ItemProperty -Path $ActiveSetupRegPath -Name 'Version' -Value '1' -Force
            Set-ItemProperty -Path $ActiveSetupRegPath -Name 'StubPath' -Value $ActiveSetupValue -Force
        }
    } catch {
        Write-Warning -Message $_.Exception.Message
    }
}

Function Get-Shortcuts
{
  $Shortcuts = @()
  $Shortcuts += Get-ChildItem -ErrorAction SilentlyContinue -Recurse -Force "C:\Users" -Include *.url
  $Shortcuts += Get-ChildItem -ErrorAction SilentlyContinue -Recurse -Force "C:\Users" -Include *.lnk
  $Shortcuts += Get-ChildItem -ErrorAction SilentlyContinue -Recurse "C:\ProgramData\Microsoft\Windows\Start Menu" -Include *.url
  $Shortcuts += Get-ChildItem -ErrorAction SilentlyContinue -Recurse "C:\ProgramData\Microsoft\Windows\Start Menu" -Include *.lnk

  $Shell = New-Object -ComObject WScript.Shell
  foreach ($Shortcut in $Shortcuts)
  {
      $Properties = @{
      ShortcutName = $Shortcut.Name;
      Path = $Shortcut.FullName;
      ShortcutDirectory = $shortcut.DirectoryName
      Target = $Shell.CreateShortcut($Shortcut).targetpath
      }
      New-Object PSObject -Property $Properties
  }

  [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
}

<#
 .Synopsis
  Create a shortcut
 .Parameter Name
  Name of shortcut
 .Parameter TargetPath
  TargetPath of shortcut
 .Parameter WorkingDirectory
  Working Directory of shortcut
 .Parameter IconLocation
  Icon location for shortcut
 .Parameter Arguments
  Arguments for the program executed by shortcut
 .Parameter shortcuts
  Specify where you want to shortcut created: ('None','Desktop','StartMenu','Startup','CommonDesktop','CommonStartMenu','CommonStartup')
 .Parameter RunAsAdministrator
  Include this switch if you want the shortcut to be set to Run As Administrator
#>
Function Create-Shortcut {
  Param (
      [Parameter(Mandatory=$true)]
      [string] $Name,
      [Parameter(Mandatory=$true)]
      [string] $TargetPath,
      [string] $WorkingDirectory = "",
      [string] $IconLocation = "",
      [string] $Arguments = "",
      [ValidateSet('None','Desktop','StartMenu','Startup','CommonDesktop','CommonStartMenu','CommonStartup','DesktopFolder','CommonDesktopFolder')]
      [string] $shortcuts = "Desktop",
      [switch] $RunAsAdministrator = $isAdministrator
  )
  $folderName = ""
  if ($shortcuts.EndsWith("Folder")) {
      $shortcuts = $shortcuts.Substring(0,$shortcuts.Length - 6)
      $folderName = $name.Split(' ')[0]
      $name = $name.Substring($folderName.Length).TrimStart(' ')
  }
  if ($shortcuts -ne "None") {

      if ($shortcuts -eq "Desktop" -or
          $shortcuts -eq "CommonDesktop" -or
          $shortcuts -eq "Startup" -or
          $shortcuts -eq "CommonStartup") {

          $folder = [Environment]::GetFolderPath($shortcuts)
      } else {
          $folder = [Environment]::GetFolderPath($shortcuts)
          if (!(Test-Path $folder -PathType Container)) {
              New-Item $folder -ItemType Directory | Out-Null
          }
      }

      if ($folder) {
          if ($folderName) {
             $folder = Join-Path $folder $folderName
             if (!(Test-Path $folder -PathType Container)) {
                 New-Item $folder -ItemType Directory | Out-Null
             }
          }

          $filename = Join-Path $folder "$Name.lnk"
          if (Test-Path -Path $filename) {
              Remove-Item $filename -force
          }

          $tempfilename = Join-Path "$ENV:LOCALAPPDATA\temp" "$([Guid]::NewGuid().ToString()).lnk"
          $Shell =  New-object -comobject WScript.Shell
          $Shortcut = $Shell.CreateShortcut($tempfilename)
          $Shortcut.TargetPath = $TargetPath
          if (!$WorkingDirectory) {
              $WorkingDirectory = Split-Path $TargetPath
          }
          $Shortcut.WorkingDirectory = $WorkingDirectory
          if ($Arguments) {
              $Shortcut.Arguments = $Arguments
          }
          if ($IconLocation) {
              $Shortcut.IconLocation = $IconLocation
          }
          $Shortcut.save()

          if ($RunAsAdministrator) {
              $bytes = [System.IO.File]::ReadAllBytes($tempfilename)
              $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
              [System.IO.File]::WriteAllBytes($tempfilename, $bytes)
          }

          Move-Item -Path $tempfilename -Destination $filename -ErrorAction SilentlyContinue
      }
  }
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

# Import active directory module for running AD cmdlets
Import-Module ActiveDirectory

# Import exchange
. 'C:\Program Files\Microsoft\Exchange Server\V15\bin\RemoteExchange.ps1'
Connect-ExchangeServer -auto

# Read in a list of IDs to create user accounts for
$ADUsers = Get-Content .\contestant_id_list.txt

# Define shared properties
$UPN = "tcalocal.com"
$DefaultPass = "changeme"
$Ou = "OU=Students,OU=TCA,DC=tcalocal,DC=com"
$firstName = "Contestant"
$UsernameSuffix = ".25"
$ExchangePermissionGrantUser = "damik@tcalocal.com"
$HomeDirectoryRoot = "F:\Shares\Users"

# Loop through each row containing user details in the CSV file
foreach ($User in $ADUsers) {

    if (!$User) {
        continue
    }

    #Read user data from each field in each row and assign the data to a variable as below
    $username = $User + $UsernameSuffix
    $password = $DefaultPass
    $firstname = $firstName
    $lastname = $User
    $OU = $Ou
    $email = $username + '@' + $UPN

    # Check to see if the user already exists in AD
    $adUser = Get-ADUser -F { SamAccountName -eq $username }
    if ($adUser) {
        # If user does exist, give a warning
        Write-Warning "A user account with username $username already exists in Active Directory."
    }
    else {
        # User does not exist then proceed to create the new user account
        # Account will be created in the OU provided by the $OU variable read from the CSV file
        $adUser = New-ADUser `
            -SamAccountName $username `
            -UserPrincipalName "$username@$UPN" `
            -Name "$firstname $lastname" `
            -GivenName $firstname `
            -Surname $lastname `
            -Enabled $True `
            -DisplayName "$firstname $lastname" `
            -Path $OU `
            -EmailAddress $email `
            -AccountPassword (ConvertTo-secureString $password -AsPlainText -Force) -ChangePasswordAtLogon $True

        # If user is created, show message.
        Write-Host "The user account $username is created." -ForegroundColor Cyan
        Start-Sleep -Seconds 5 # wait for creation

        # populate var with correct value for further steps
        $adUser = Get-ADUser -F { SamAccountName -eq $username }
    }

    # Setup user vars
    $userHomeDirectory = Join-Path -Path $HomeDirectoryRoot -ChildPath $username
    $userProfileDirectory = Join-Path -Path $userHomeDirectory -ChildPath "Profile"
    $userUpn = $adUser.UserPrincipalName

    # Setup user Directory and set owner
    if ( -not (Test-Path $userProfileDirectory)){
        force-mkdir $userProfileDirectory # create profile dir and root home directory
        Write-Host "The user directory for $username is created." -ForegroundColor Cyan
    } else {
        Write-Warning "Directory for user $username already exists."
    }

    # Ensure ACL is set on home directory
    $acl = Get-Acl $userHomeDirectory
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule (
        $adUser.SID, 'ReadAndExecute, Modify, Synchronize', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    )))
    Set-Acl $userHomeDirectory $acl

    # setup user mailbox
    $mailboxExist = [bool](Get-Mailbox -Identity $adUser.UserPrincipalName -erroraction SilentlyContinue)
    if (!$mailboxExist) {
        Enable-Mailbox -Identity ($adUser.UserPrincipalName)
        Write-Host "Enabled mailbox for $userUpn"
    } else {
        Write-Warning "A mailbox already exists for $userUpn"
    }

    # Add access to mailbox
    Add-MailboxPermission -Identity ($adUser.UserPrincipalName) -User $ExchangePermissionGrantUser -AccessRights FullAccess -InheritanceType All
}

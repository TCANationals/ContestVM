# Import active directory module for running AD cmdlets
Import-Module ActiveDirectory
Import-Module AWS.Tools.SSOAdmin
Import-Module AWS.Tools.SSO
Import-Module AWS.Tools.IdentityStore

# Import exchange
. 'C:\Program Files\Microsoft\Exchange Server\V15\bin\RemoteExchange.ps1'
Connect-ExchangeServer -auto

# Read in a list of IDs to create user accounts for
$ADUsers = Get-Content .\contestant_id_list.txt

# Define shared properties
$awsSSOIdStore = "d-906742eef4"
$awsSSOGroupId = "e488d4a8-10e1-7049-2617-d6c122af219e" # Everyone
$UPN = "tcalocal.com"
$DefaultPass = "changeme"
$Ou = "OU=Students,OU=TCA,DC=tcalocal,DC=com"
$firstName = "Contestant"
$UsernameSuffix = ".24"
$ExchangePermissionGrantUser = "damik@tcalocal.com"

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
    }

    # setup user mailbox
    $mailboxExist = [bool](Get-Mailbox -Identity $adUser.UserPrincipalName -erroraction SilentlyContinue)
    if (!$mailboxExist) {
        Enable-Mailbox -Identity ($adUser.UserPrincipalName)
        Write-Host "Enabled mailbox for " $adUser.UserPrincipalName
    } else {
        Write-Warning "A mailbox already exists for " $adUser.UserPrincipalName
    }

    # Add access to mailbox
    Add-MailboxPermission -Identity ($adUser.UserPrincipalName) -User $ExchangePermissionGrantUser -AccessRights FullAccess -InheritanceType All

    # Make sure user is setup in SSO
    # try {
    #     $ssoUserId = Get-IDSUserId -IdentityStoreId $awsSSOIdStore -UniqueAttribute_AttributePath 'Username' -UniqueAttribute_AttributeValue $email
    #     Write-Warning "A user account with username $username already exists in AWS SSO (ID = $ssoUserId)."
    # } catch {
    #     $ssoEmail = New-Object Amazon.IdentityStore.Model.Email
    #     $ssoEmail.Value = $email
    #     $ssoUserId = New-IDSUser -IdentityStoreId $awsSSOIdStore -Name_FamilyName $lastname -Name_GivenName $firstname -DisplayName "$firstname $lastname" -UserName $email -Email $ssoEmail
    #     Write-Host "A user account does not exist for provided email, creating one..."
    # }

    # # Verify SSO group membership
    # $groupMembershipCheck = Assert-IDSMemberInGroup -IdentityStoreId $awsSSOIdStore -GroupId $awsSSOGroupId -MemberId_UserId $ssoUserId
    # if (!$groupMembershipCheck.MembershipExists) {
    #     Write-Warning "User with ID $ssoUserId is not member of group, adding..."
    #     New-IDSGroupMembership -IdentityStoreId $awsSSOIdStore -GroupId $awsSSOGroupId -MemberId_UserId $ssoUserId
    # }
}

# Import active directory module for running AD cmdlets
Import-Module ActiveDirectory

# Read in a list of IDs to create user accounts for
$ADUsers = Get-Content .\contestant_id_list.txt

# Define shared properties
$UPN = "tcalocal.com"
$DefaultPass = "changeme"
$Ou = "OU=Students,OU=TCA,DC=tcalocal,DC=com"
$UsernameSuffix = ".22"

# Loop through each row containing user details in the CSV file
foreach ($User in $ADUsers) {

    if (!$User) {
        continue
    }

    #Read user data from each field in each row and assign the data to a variable as below
    $username = $User + $UsernameSuffix
    $password = $DefaultPass
    $firstname = "Contestant"
    $lastname = $User
    $OU = $Ou
    $email = $username + '@' + $UPN

    # Check to see if the user already exists in AD
    if (Get-ADUser -F { SamAccountName -eq $username }) {
        # If user does exist, give a warning
        Write-Warning "A user account with username $username already exists in Active Directory."
    }
    else {
        # User does not exist then proceed to create the new user account
        # Account will be created in the OU provided by the $OU variable read from the CSV file
        New-ADUser `
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
    }
}

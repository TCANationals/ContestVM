# Generate a specified number of fake emails with a mix of legitimate, spam, and security content

# Import the Outlook application
#Add-Type -AssemblyName Microsoft.Office.Interop.Outlook

# Create a new Outlook application object
#$outlook = New-Object -ComObject Outlook.Application

$from_email = @(
    "mailinator.com",
    "guerrillamail.com",
    "temp-mail.org",
    "dispostable.com",
    "sharklasers.com",
    "yopmail.com",
    "getairmail.com",
    "10minutemail.com",
    "tempail.com",
    "throwawaymail.com",
    "tcanationals.com",
    "skillsusa.org",
    "google.com"
)

$from_name = @(
    "John Smith, CEO <jsmith@",
    "Sarah Johnson, CFO <sarah@",
    "Michael Lee, CTO <mlee@",
    "Rachel Brown, COO <rb@",
    "Lisa Davis, HR Director <lisa@",
    "David Miller, Marketing Director <marketing@",
    "Emily Taylor, Sales Director <em@",
    "Jason Scott, Operations Manager <js@",
    "Michelle Nguyen, Project Manager <michelle@",
    "Andrew Patel, IT Manager <apatel@",
    "Stephanie Chen, Business Analyst <stephanie@",
    "Samantha Garcia, Account Manager <sg@",
    "Steven Thompson, Customer Service Manager <csm@",
    "Alex Wilson, Communications Manager <alexw@",
    "Jennifer Green, Legal Counsel <jeng@",
    "Jessica Kim, Public Relations Manager <jkim@",
    "Eric Chen, Procurement Manager <echen@",
    "Karen Davis, Executive Assistant <karen.davis@",
    "Brian Jackson, Administrative Assistant <brian@",
    "Kevin Lee, Office Manager <kevin.lee@"
)

# Specify the number of emails to generate for each address
$num_emails = 100

# Define arrays of legitimate, spam, and security subjects and bodies
$legitimate_subjects = @(
    "Reminder: Upcoming meeting",
    "Thank you for your purchase",
    "Important information about your account",
    "Request for information",
    "Confirmation of reservation"
)
$legitimate_bodies = @(
    "Hello, this is a reminder that we have a meeting scheduled for tomorrow at 2:00 PM. Please be on time and come prepared with any necessary materials. Thank you.",
    "Thank you for your recent purchase. If you have any questions or concerns, please don't hesitate to contact us.",
    "We have detected some unusual activity on your account. Please review the attached document and contact us if you have any questions.",
    "We are requesting some additional information from you. Please see the attached form and return it to us as soon as possible.",
    "This email is to confirm your reservation for the upcoming event. If you have any changes or updates, please let us know."
)
$spam_subjects = @(
    "Amazing offers for you!",
    "Don't miss out on this incredible opportunity",
    "Congratulations! You've been selected",
    "Limited time offer",
    "Your account has been suspended"
)
$spam_bodies = @(
    "Congratulations! You have been selected to receive exclusive offers on the latest products and services. Click on the link below to claim your reward now!",
    "Don't miss out on this incredible opportunity to earn easy money. Click the link below to get started today.",
    "You've been selected to receive a special gift. Click on the link below to claim your prize now!",
    "This offer is only available for a limited time. Click on the link below to claim your discount before it expires.",
    "Your account has been suspended due to suspicious activity. Click on the link below to reactivate your account."
)
$security_subjects = @(
    "IT Security Bulletin: System Update Required",
    "Urgent: Phishing Attack Warning",
    "Important: Password Security Reminder",
    "Critical: Unauthorized Access Detected",
    "Data Breach Notification: Take Immediate Action"
)
$security_bodies = @(
    "Dear Team Members,`n`nPlease be informed that a system update is required to ensure the security and stability of our IT infrastructure. Kindly install the provided update by following the instructions in the attached document. If you have any questions or concerns, please contact the IT department.`n`nThank you for your cooperation.`n`nBest regards,`nThe IT Department",
    "Attention all employees,`n`nWe have detected a recent increase in phishing attacks targeting our organization. It is crucial to remain vigilant and exercise caution when interacting with emails and websites. Remember to report any suspicious activity to the IT department immediately. Stay safe and protect our network.`n`nRegards,`nThe IT Security Team",
    "Dear Team,`n`nThis is a friendly reminder to review and update your passwords regularly to maintain strong security. Passwords should be unique, complex, and not shared with others. If you need assistance or have questions regarding password best practices, please reach out to the IT department.`n`nThank you for your cooperation.`n`nSincerely,`nThe IT Security Team",
    "Attention all employees,`n`nWe have detected an unauthorized access attempt to our network. Our security systems have taken immediate action to block the intrusion. However, we strongly advise you to remain cautious and report any suspicious activities or anomalies to the IT department promptly. Your vigilance is essential to maintaining a secure environment.`n`nBest regards,`nThe IT Security Team",
    "Dear Team,`n`nWe regret to inform you that a data breach has occurred, potentially exposing sensitive information. Immediate action is required to protect both personal and company data. Please review the attached document for detailed instructions on how to safeguard your information. If you have any questions, contact the IT department immediately.`n`nBest regards,`nThe IT Security Team"
)

# Read the email addresses from the provided .txt file
$raw_email_addresses = Get-Content -Path "email_addresses.txt"
$email_addresses = New-Object System.Collections.ArrayList
foreach ($email in $raw_email_addresses) {
    $email_addresses.Add($email) | Out-Null
}

# Send the emails for each email address
$email_addresses | ForEach-Object {
    Start-Job -args (
        $_,
        $legitimate_subjects,
        $legitimate_bodies,
        $spam_subjects,
        $spam_bodies,
        $security_subjects,
        $security_bodies,
        $num_emails,
        $from_email,
        $from_name
    ) -Scriptblock {
        param(
            [string]$address,
            [string[]]$legitimate_subjects,
            [string[]]$legitimate_bodies,
            [string[]]$spam_subjects,
            [string[]]$spam_bodies,
            [string[]]$security_subjects,
            [string[]]$security_bodies,
            [int]$num_emails,
            [string[]]$from_email,
            [string[]]$from_name
        )

        # Send the specified number of emails for each address
        $startTime = (Get-Date)
        Write-Host "Sending email batch to $address"

        for ($i = 1; $i -le $using:num_emails; $i++) {
            # Determine whether this email should be legitimate, spam, or security
            $email_type = Get-Random -Minimum 0 -Maximum 3

            $from_name_idx = Get-Random -Minimum 0 -Maximum $from_name.Length
            $from_name_str = $from_name[$from_name_idx]
            $from_domain_idx = Get-Random -Minimum 0 -Maximum $from_email.Length
            $from_domain_str = $from_email[$from_domain_idx]
            $from_email_compiled = "$from_name_str$from_domain_str>"

            if ($email_type -eq 0) {
                # Select a random legitimate subject and body
                $legitimate_index = Get-Random -Minimum 0 -Maximum $legitimate_subjects.Length
                $subject = $legitimate_subjects[$legitimate_index]
                $body = $legitimate_bodies[$legitimate_index]
            }
            elseif ($email_type -eq 1) {
                # Select a random spam subject and body
                $spam_index = Get-Random -Minimum 0 -Maximum $spam_subjects.Length
                $subject = $spam_subjects[$spam_index]
                $body = $spam_bodies[$spam_index]
            }
            else {
                # Select a random security subject and body
                $security_index = Get-Random -Minimum 0 -Maximum $security_subjects.Length
                $subject = $security_subjects[$security_index]
                $body = $security_bodies[$security_index]
            }

            # Create a new email object
            #$mail = $outlook.CreateItem(0)
            
            $priority = Get-Random -Minimum 0 -Maximum 3

            Send-MailMessage -SmtpServer 'tca-exch1' -From $from_email_compiled -To $address -Subject $subject -Body $body -Priority $priority

            # Set the email properties
            #$mail.To = $address
            #$mail.Subject = $subject
            #$mail.Body = $body
            #$mail.Importance = 2

            # Send the email
            #$mail.Send()
        }

        $endTime = (Get-Date)
        $finalTime = ($endTime - $startTime)
        Write-Host "Finished email batch to $address in" $finalTime
    }
} | Receive-Job -Wait -AutoRemoveJob


Write-Host "Finished sending batch"

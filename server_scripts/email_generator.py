import smtplib
import random
import re
from email.mime.text import MIMEText
from email.utils import formataddr, make_msgid
from email.message import EmailMessage
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

# Define sender domains and names
from_email = [
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
    "google.com",
    "amazon.com",
]

from_name = [
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
    "Kevin Lee, Office Manager <kevin.lee@",
]

# Define email content
legitimate_subjects = [
    "Reminder: Upcoming meeting",
    "Thank you for your purchase",
    "Important information about your account",
    "Request for information",
    "Confirmation of reservation",
]

legitimate_bodies = [
    "Hello, this is a reminder that we have a meeting scheduled for tomorrow at 2:00 PM. Please be on time and come prepared with any necessary materials. Thank you.",
    "Thank you for your recent purchase. If you have any questions or concerns, please don't hesitate to contact us.",
    "We have detected some unusual activity on your account. Please review the attached document and contact us if you have any questions.",
    "We are requesting some additional information from you. Please see the attached form and return it to us as soon as possible.",
    "This email is to confirm your reservation for the upcoming event. If you have any changes or updates, please let us know.",
]

spam_subjects = [
    "Amazing offers for you!",
    "Don't miss out on this incredible opportunity",
    "Congratulations! You've been selected",
    "Limited time offer",
    "Your account has been suspended",
]

spam_bodies = [
    "Congratulations! You have been selected to receive exclusive offers on the latest products and services. Click on the link below to claim your reward now!",
    "Don't miss out on this incredible opportunity to earn easy money. Click the link below to get started today.",
    "You've been selected to receive a special gift. Click on the link below to claim your prize now!",
    "This offer is only available for a limited time. Click on the link below to claim your discount before it expires.",
    "Your account has been suspended due to suspicious activity. Click on the link below to reactivate your account.",
]

security_subjects = [
    "IT Security Bulletin: System Update Required",
    "Urgent: Phishing Attack Warning",
    "Important: Password Security Reminder",
    "Critical: Unauthorized Access Detected",
    "Data Breach Notification: Take Immediate Action",
]

security_bodies = [
    "Dear Team Members,\n\nPlease be informed that a system update is required to ensure the security and stability of our IT infrastructure. Kindly install the provided update by following the instructions in the attached document. If you have any questions or concerns, please contact the IT department.\n\nThank you for your cooperation.\n\nBest regards,\nThe IT Department",
    "Attention all employees,\n\nWe have detected a recent increase in phishing attacks targeting our organization. It is crucial to remain vigilant and exercise caution when interacting with emails and websites. Remember to report any suspicious activity to the IT department immediately. Stay safe and protect our network.\n\nRegards,\nThe IT Security Team",
    "Dear Team,\n\nThis is a friendly reminder to review and update your passwords regularly to maintain strong security. Passwords should be unique, complex, and not shared with others. If you need assistance or have questions regarding password best practices, please reach out to the IT department.\n\nThank you for your cooperation.\n\nSincerely,\nThe IT Security Team",
    "Attention all employees,\n\nWe have detected an unauthorized access attempt to our network. Our security systems have taken immediate action to block the intrusion. However, we strongly advise you to remain cautious and report any suspicious activities or anomalies to the IT department promptly. Your vigilance is essential to maintaining a secure environment.\n\nBest regards,\nThe IT Security Team",
    "Dear Team,\n\nWe regret to inform you that a data breach has occurred, potentially exposing sensitive information. Immediate action is required to protect both personal and company data. Please review the attached document for detailed instructions on how to safeguard your information. If you have any questions, contact the IT department immediately.\n\nBest regards,\nThe IT Security Team",
]

# Regular expression pattern to match email inside angle brackets `<>`
email_pattern = r'<([^<>]+)>'

num_emails = 10

# Read email addresses from file
with open('email_addresses.txt', 'r') as file:
    email_addresses = [line.strip() for line in file]

def send_email(address, legitimate_subjects, legitimate_bodies, spam_subjects, spam_bodies, security_subjects, security_bodies, num_emails, from_email, from_name):
    start_time = datetime.now()
    print(f"Sending email batch to {address}")

    for _ in range(num_emails):
        server = smtplib.SMTP('TCA-EXCH1.tcalocal.com')
        email_type = random.randint(0, 2)
        from_name_idx = random.randint(0, len(from_name) - 1)
        from_domain_idx = random.randint(0, len(from_email) - 1)
        from_email_compiled = f"{from_name[from_name_idx]}{from_email[from_domain_idx]}>"
        priority = random.randint(0, 2)
        from_email_address_rx = re.search(email_pattern, from_email_compiled)
        from_email_address = from_email_address_rx.group(1)

        if email_type == 0:
            subject = random.choice(legitimate_subjects)
            body = random.choice(legitimate_bodies)
        elif email_type == 1:
            subject = random.choice(spam_subjects)
            body = random.choice(spam_bodies)
        else:
            subject = random.choice(security_subjects)
            body = random.choice(security_bodies)

        #msg = MIMEText(body)
        msg = EmailMessage()
        msg.set_content(body)
        msg['From'] = from_email_compiled
        msg['To'] = address
        msg['Subject'] = subject
        msg['Message-ID'] = make_msgid(domain='tcalocal.com')
        msg['X-Priority'] = f"{priority}"

        try:
            server.send_message(msg, from_email_address, [address])
        except smtplib.SMTPException as e:
            print(f"Error sending email to {address}: {e}")

    end_time = datetime.now()
    final_time = end_time - start_time
    print(f"Finished email batch to {address} in {final_time}")

# Use ThreadPoolExecutor to parallelize the task
with ThreadPoolExecutor() as executor:
    futures = [executor.submit(send_email, address, legitimate_subjects, legitimate_bodies, spam_subjects, spam_bodies, security_subjects, security_bodies, num_emails, from_email, from_name) for address in email_addresses]

# Ensuring all threads have completed
for future in futures:
    future.result()

print("Finished sending batch")

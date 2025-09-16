# Smtp configuration
$smtpServer = "smtp.gmail.com"
$smtpPort = 587
$emailFrom = "michaelovsky5@gmail.com"
$emailTo = "michaelovsky5@gmail.com"

# Ask for credentials securely
$credentials = Get-Credential -UserName $emailFrom -Message "Enter your Gmail App Password"

# The URL to monitor
$url = "https://api.ferdium.org/user/login"
$previousStatus = $null
$sentTestMail = $false

# Function to send email
function Send-FerdiumStatusEmail {
    param (
        [string]$Subject,
        [string]$Body
    )

    try {
        Write-Host "Sending email with subject: '$Subject'..."
        Send-MailMessage -From $emailFrom -To $emailTo -Subject $Subject -Body $Body -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential $credentials
        Write-Host "Email sent successfully."
    } catch {
        Write-Host "Failed to send email. Error: $_"
    }
}

# Send a test email right now to check setup
Write-Host "Performing initial check and sending a test email."
Send-FerdiumStatusEmail -Subject "Ferdium Status Script Test" -Body "This is a test email from your Ferdium status monitor script."

while ($true) {
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -ErrorAction SilentlyContinue
        $currentStatus = "up"
    } catch {
        $currentStatus = "down"
    }
    
    # Compare status and send a real-time email if it changes
    if ($previousStatus -ne $null -and $currentStatus -ne $previousStatus) {
        if ($currentStatus -eq "up") {
            $subject = "Ferdium is UP!"
            $body = "The Ferdium API is now back online."
            Send-FerdiumStatusEmail -Subject $subject -Body $body
        } else {
            $subject = "Ferdium is DOWN!"
            $body = "The Ferdium API is now down."
            Send-FerdiumStatusEmail -Subject $subject -Body $body
        }
    }

    $previousStatus = $currentStatus
    Write-Host "Status checked. Current status: $currentStatus. Waiting 60 seconds."
    Start-Sleep -Seconds 60
}

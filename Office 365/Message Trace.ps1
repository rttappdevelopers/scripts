# Message Trace Script
Set-ExecutionPolicy RemoteSigned

# Is the Exchange Online Management PowerShell module installed? If not, install it
Write-Output "Connecting to Office 365"
if (!(Get-InstalledModule -Name "ExchangeOnlineManagement")) {
        Install-Module -Name ExchangeOnlineManagement
        Import-Module ExchangeOnlineManagement
    }
    else {
        Import-Module ExchangeOnlineManagement
    }

# Connect to Office 365 platform
Connect-ExchangeOnline

# Gather parameters
$sender = Read-Host "Enter sender email address (* for all)"
$recipient = Read-Host "Enter recipient email address (* for all)"
$subject = Read-Host "Enter subject (supports wildcards like *keyword*, leave blank for all)"
$days = Read-Host "How many days back to search? (1-10, default is 2)"

if ([string]::IsNullOrWhiteSpace($days) -or $days -gt 10) {
    $days = 2
}

$startDate = (Get-Date).AddDays(-$days)
$endDate = Get-Date

# Build parameters for Get-MessageTrace
$params = @{
    StartDate = $startDate
    EndDate = $endDate
}

if ($sender -ne "*" -and ![string]::IsNullOrWhiteSpace($sender)) {
    $params.Add("SenderAddress", $sender)
}

if ($recipient -ne "*" -and ![string]::IsNullOrWhiteSpace($recipient)) {
    $params.Add("RecipientAddress", $recipient)
}

Write-Output "`nSearching messages from $startDate to $endDate..."

# Get message trace
$messages = Get-MessageTrace @params

# Filter by subject if provided
if (![string]::IsNullOrWhiteSpace($subject)) {
    $messages = $messages | Where-Object { $_.Subject -like $subject }
}

# Display and export results
if ($messages) {
    Write-Output "`nFound $($messages.Count) message(s):"
    $messages | Select-Object Received, SenderAddress, RecipientAddress, Subject, Status, Size | Format-Table -AutoSize
    
    $messages | Select-Object Received, SenderAddress, RecipientAddress, Subject, Status, Size, MessageId | Export-CSV "C:\temp\messagetrace.csv" -NoTypeInformation
    Write-Output "`nResults exported to C:\temp\messagetrace.csv"
} else {
    Write-Output "`nNo messages found matching the criteria."
}
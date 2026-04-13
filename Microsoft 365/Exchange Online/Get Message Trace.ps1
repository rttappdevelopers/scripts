#Requires -Version 7
<#
.SYNOPSIS
    Performs an Exchange Online message trace and exports results to CSV.

.DESCRIPTION
    Connects to Exchange Online and searches for messages matching the specified
    sender, recipient, subject, and date range criteria. Results are displayed
    in a table and exported to C:\temp\messagetrace.csv.

.NOTES
    Name:    Get Message Trace
    Author:  RTT Support
    Context: Technician workstation (interactive)
#>

param()

# Is the Exchange Online Management PowerShell module installed? If not, install it
Write-Output "Connecting to Office 365"
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# Connect to Office 365 platform
# -DisableWAM bypasses Web Account Manager to fix sign-in errors in elevated/non-standard terminals (e.g. running from C:\WINDOWS\system32).
Connect-ExchangeOnline -DisableWAM

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

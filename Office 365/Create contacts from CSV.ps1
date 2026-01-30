# Description: This script creates mail contacts in Exchange Online from a CSV file containing email addresses and names.

# Install Exchange Online module if not already installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
}

# Import the module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline

# Define the CSV file path
$csvPath = Read-Host "Enter the path to your CSV file (e.g., C:\contacts.csv)"
$csvPath = $csvPath -replace '^"|"$', ''

# Validate file exists
if (-not (Test-Path $csvPath)) {
    Write-Error "CSV file not found at $csvPath"
    exit
}

# Import CSV data
$contacts = Import-Csv -Path $csvPath

# Create contacts from CSV
foreach ($contact in $contacts) {
    $params = @{
        Name           = "$($contact.Firstname) $($contact.Lastname)"
        ExternalEmailAddress = $contact.Email
        DisplayName    = "$($contact.Firstname) $($contact.Lastname)"
    }
    
    try {
        New-MailContact @params
        Write-Host "Created contact: $($params.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create contact for $($contact.'Email Address'): $_" -ForegroundColor Red
    }
}

Write-Host "Contact creation complete." -ForegroundColor Cyan
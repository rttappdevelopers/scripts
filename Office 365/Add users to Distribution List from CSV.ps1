# Description: This script adds users to a distribution list in Exchange Online from a CSV file containing email addresses.

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

# Get the distribution list
$distributionList = Read-Host "Enter the distribution list email address or name (e.g., team@contoso.com)"

# Validate the distribution list exists
try {
    $dlObject = Get-DistributionGroup -Identity $distributionList -ErrorAction Stop
    Write-Host "Found distribution list: $($dlObject.DisplayName)" -ForegroundColor Green
}
catch {
    Write-Error "Distribution list not found: $distributionList"
    exit
}

# Import CSV data
$users = Import-Csv -Path $csvPath

# Add users to distribution list
foreach ($user in $users) {
    try {
        Add-DistributionGroupMember -Identity $dlObject.Identity -Member $user.Email -ErrorAction Stop
        Write-Host "Added $($user.Email) to $($dlObject.DisplayName)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to add $($user.Email): $_" -ForegroundColor Red
    }
}

Write-Host "Distribution list update complete." -ForegroundColor Cyan

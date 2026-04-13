#Requires -Version 7
<#
.SYNOPSIS
    Adds users to an Exchange Online distribution list from a CSV file.

.DESCRIPTION
    Connects to Exchange Online and adds email addresses from a CSV file
    (containing an Email column) to the specified distribution group.

.NOTES
    Name:    Add Users to Distribution List
    Author:  RTT Support
    Context: Technician workstation (interactive)
#>

param()

# Install Exchange Online module if not already installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
}

# Import the module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
# -DisableWAM bypasses Web Account Manager to fix sign-in errors in elevated/non-standard terminals (e.g. running from C:\WINDOWS\system32).
Connect-ExchangeOnline -DisableWAM

# Define the CSV file path
$csvPath = Read-Host "Enter the path to your CSV file (e.g., C:\contacts.csv)"
$csvPath = $csvPath -replace '^"|"$', ''

# Validate file exists
if (-not (Test-Path $csvPath)) {
    throw "CSV file not found at $csvPath"
}

# Get the distribution list
$distributionList = Read-Host "Enter the distribution list email address or name (e.g., team@contoso.com)"

# Validate the distribution list exists
try {
    $dlObject = Get-DistributionGroup -Identity $distributionList -ErrorAction Stop
    Write-Host "Found distribution list: $($dlObject.DisplayName)" -ForegroundColor Green
}
catch {
    throw "Distribution list not found: $distributionList"
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

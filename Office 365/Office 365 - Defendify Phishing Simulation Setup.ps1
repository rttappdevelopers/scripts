### DEPCRECATED, see https://office365itpros.com/2023/04/17/compliance-endpoint-powershell/ ###
### https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2?view=exchange-ps#updates-for-version-300-the-exo-v3-module ###

# Add Defendify Phishing Simulation allowances to a customer's Office 365 tenant
## Reference: https://app.defendify.com/module/phishing-simulations/whitelisting
## Reference: https://learn.microsoft.com/en-us/powershell/exchange/connect-to-scc-powershell?view=exchange-ps
## Reference: https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/skip-filtering-phishing-simulations-sec-ops-mailboxes?view=o365-worldwide

# Settings
# Replace these variables as needed

$PhishingDomains = @(
    "amaznshipping.com",
    "apple-messenger.com",
    "defendify.com",
    "defendify.net",
    "diversitymattersmost.org",
    "egiftcard.zone",
    "getdropbox.net",
    "getpassword.help",
    "googlalerts.news",
    "linkedinvitations.com",
    "message.fail",
    "resetmypassword.link",
    "shipment-update.com",
    "slcknotifier.com",
    "ticktokapp.com",
    "us-gov.org",
    "vemnopayment.com",
    "zoomeetings.us"
)

$PhishingIPs = @(
    "108.61.75.52",
    "149.28.42.39",
    "207.246.122.254"
)

# Check for module ExchangeOnlineManagement and get current version if present, install if not present, upgrade if newer version than current is available
if (-Not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
    Write-Output "Installing Exchange Online Management PowerShell module.`n"
    Install-Module -Name ExchangeOnlineManagement -Force
} else {
    $CurrentVersion = (Get-Module -Name ExchangeOnlineManagement).Version
    $NewVersion = (Find-Module -Name ExchangeOnlineManagement).Version
    if ($NewVersion -gt $CurrentVersion) {
        Write-Output "Updating Exchange Online Management PowerShell module from $CurrentVersion to $NewVersion.`n"
        Update-Module -Name ExchangeOnlineManagement -Force
    }
}
Import-Module ExchangeOnlineManagement

# Connect to MS 365 Security & Compliance Center and set phishing override policy
Write-Output "Connecting to Office 365 for anti-phishing overrides, look for a pop-up window requesting credentials.`n"
Connect-IPPSSession

## Check for existing phishing override policy and create one if it one doesn't exist (there can be only one or there's an error)
if ($null -eq (Get-PhishSimOverridePolicy | Select-Object Name)) { 
    Write-Output "Creating new Phishing Simulation Override Policy.`n"
    New-PhishSimOverridePolicy -Name PhishSimOverridePolicy 
}

## Add new phishing override policy, removing current to replace existing
$F20PhishingDomains = $PhishingDomains | Select-Object -First 20  # There is a limit to 20 domains in a Phishing Simulation Policy
if (-Not $null -eq (Get-PhishSimOverriderule -Policy "PhishSimOverridePolicy")) { 
    Write-Output "Removing existing Phishing Simulation Override Policy.`n"
    Get-PhishSimOverriderule  -Policy "PhishSimOverridePolicy" | Remove-PhishSimOverrideRule 
}

Write-Output "Adding domains and IP addresses to the Phishing Simulation Override Policy.`n"
New-PhishSimOverrideRule -Name PhishSimOverridePolicy -Policy PhishSimOverridePolicy -Domains $F20PhishingDomains -SenderIpRanges $PhishingIPs

# Connect to Exchange Online Management to update default Connection Filter Policy to include IP addresses and domains
Write-Output "Connecting to Office 365 for anti-spam overrides, look for a pop-up window requesting credentials.`n"
Connect-ExchangeOnline

# Enable-OrganizationCustomization. This is required to allow the use of the Set-HostedConnectionFilterPolicy cmdlet
if (-not (Get-OrganizationConfig).IsDehydrated) {
    Write-Output "Organization customization is already enabled.`n"
} else {
    Write-Output "Enabling Organization Customization. If the next commands generate an error stating that Organization Customization isn't enabled, wait 24 hours and try again.`n"
    Enable-OrganizationCustomization
    Start-Sleep -Seconds 10  # Wait for organization customization to take effect
}

## Add IP addresses to Connection Filter Policy
Write-Output "Adding IP addresses to Connection Filter Policy.`n"
Set-HostedConnectionFilterPolicy "Default" -IPAllowList $PhishingIPs

## Add domains to Anti-Spam Inbound Policy
Write-Output "Adding domains to Anti-Spam Inbound Policy.`n"
Set-HostedContentFilterPolicy -Identity 'Default' -AllowedSenderDomains $PhishingDomains

# Cleanup and disconnect
Write-Output "Tasks completed."
#Disconnect-ExchangeOnline
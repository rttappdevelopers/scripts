# Add Defendify Phishing Simulation allowances to a customer's Office 365 tenant
## Reference: https://app.defendify.com/module/phishing-simulations/whitelisting
## Reference: https://learn.microsoft.com/en-us/powershell/exchange/connect-to-scc-powershell?view=exchange-ps
## Reference: https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/skip-filtering-phishing-simulations-sec-ops-mailboxes?view=o365-worldwide
$ErrorActionPreference = "Stop"

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

# Connect to MS 365 Security & Compliance Center and set phishing override policy
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -ErrorAction SilentlyContinue
Import-Module ExchangeOnlineManagement

Write-Output "Connecting to Office 365 for Phishing Simulation settings, look for a pop-up window requesting credentials.`n"
Connect-IPPSSession

## Check for existing phishing override policy and create one if it one doesn't exist (there can be only one or there's an error)
if ($null -eq (Get-PhishSimOverridePolicy | Select-Object Name)) { New-PhishSimOverridePolicy -Name PhishSimOverridePolicy }

## Add new phishing override policy, removing current to replace existing
$F20PhishingDomains = $PhishingDomains | Select-Object -First 20  # There is a limit to 20 domains in a Phishing Simulation Policy
if (-Not $null -eq (Get-PhishSimOverriderule -Policy "PhishSimOverridePolicy")) { Get-PhishSimOverriderule  -Policy "PhishSimOverridePolicy" | Remove-PhishSimOverrideRule }
New-PhishSimOverrideRule -Name PhishSimOverridePolicy -Policy PhishSimOverridePolicy -Domains $F20PhishingDomains -SenderIpRanges $PhishingIPs

# Connect to Exchange Online Management to update default Connection Filter Policy to include IP addresses and domains
Write-Output "Connecting to Office 365 for anti-spam overrides, look for a pop-up window requesting credentials.`n"
Connect-ExchangeOnline

## Add IP addresses to Connection Filter Policy
Set-HostedConnectionFilterPolicy "Default" -IPAllowList $PhishingIPs

## Add domains to Anti-Spam Inbound Policy
Set-HostedContentFilterPolicy -Identity 'Default' -AllowedSenderDomains $PhishingDomains

# Cleanup and disconnect
Write-Output "Tasks completed."
Disconnect-ExchangeOnline
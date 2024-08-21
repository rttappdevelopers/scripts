# Add Phinsec Phishing Simulation allowances to a customer's Office 365 tenant
## Reference: https://app.Phinsec.com/module/phishing-simulations/whitelisting

# Settings
## Replace these variables as needed
$PhishingDomains = @(
    "betterphish.com",
    "shippingalerts.com",
    "amazingdealz.net",
    "berrysupply.net",
    "coronacouncil.org",
    "couponstash.net",
    "creditsafetyteam.com",
    "authenticate.com",
    "notificationhandler.com"
)

$DefendifyDomains = @(
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
    "zoomeetings.us",
    "missive.defendify.com",
    "missive.defendify.net",
    "phishing.defendify.com",
    "phishing.defendify.net"
)

$PhishingIPs = @(
    "198.2.177.227"
)

$DefendifyIPs = @(
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
if ($null -eq (Get-ExoPhishSimOverrideRule | Select-Object Name)) { 
    Write-Output "Creating new Phishing Simulation Override Policy.`n"
    New-PhishSimOverridePolicy -Name PhishSimOverridePolicy 
}

## Add new phishing override policy, removing current to replace existing
$F20PhishingDomains = $PhishingDomains | Select-Object -First 20  # There is a limit to 20 domains in a Phishing Simulation Policy
if (-Not $null -eq (Get-PhishSimOverriderule -Policy "PhishSimOverridePolicy")) { 
    Write-Output "Removing existing Phishing Simulation Override Policy.`n"
    Get-PhishSimOverriderule  -Policy "PhishSimOverridePolicy" | Remove-PhishSimOverrideRule -Confirm:$false
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

## Add/replace IP addresses to Connection Filter Policy
Write-Output "Adding IP addresses to Connection Filter Policy.`n"
Set-HostedConnectionFilterPolicy "Default" -IPAllowList @{add=$PhishingIPs; remove=$DefendifyIPs}

## Add/replace domains to Anti-Spam Inbound Policy
Write-Output "Adding domains to Anti-Spam Inbound Policy.`n"
Set-HostedContentFilterPolicy -Identity 'Default' -AllowedSenderDomains @{add=$PhishingDomains; remove=$DefendifyDomains}

# Microsoft 365 Bypass ATP Safe Links
# Look for and remove any transport rules with Defendify in the name
$DefendifyRules = Get-TransportRule | Where-Object {$_.Name -like "*Defendify*"}
if ($null -ne $DefendifyRules) {
    Write-Output "Removing existing Defendify Transport Rules.`n"
    $DefendifyRules | Remove-TransportRule -Confirm:$false
}

# Configure Bypass Safe Links rule
New-TransportRule -Name "Bypass Safe Links for Phinsec Phishing Simulations" -SenderIpRanges $PhishingIPs -SetHeaderName "X-MS-Exchange-Organization-SkipSafeLinksProcessing" -SetHeaderValue "1"
New-TransportRule -Name "Bypass Focused Inbox for Phinsec Phishing Simulations" -SenderIpRanges $PhishingIPs -SetHeaderName "X-MS-Exchange-Organization-BypassFocusedInbox" -SetHeaderValue "True"

# Cleanup and disconnect
Write-Output "Tasks completed, disconnecting."
Disconnect-ExchangeOnline -Confirm:$false
# Description: This script creates a transport rule in Exchange Online to bypass spam filtering for emails coming from AppRiver IP ranges.

# Install Exchange Online module if not already installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
}

# Import the module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline

# AppRiver IP ranges as an array for readability
$appRiverIPs = @(
    '5.152.184.128/25',
    '5.152.185.128/26',
    '8.19.118.0/24',
    '8.31.233.0/24',
    '69.20.58.224/28',
    '5.152.188.0/24',
    '199.187.164.0/24',
    '199.187.165.0/24',
    '199.187.166.0/24',
    '199.187.167.0/24',
    '69.25.26.128/26',
    '204.232.250.0/24',
    '74.203.184.184/32',
    '74.203.184.185/32',
    '199.30.235.11/32',
    '74.203.185.12/32'
)

# Splat parameters for New-TransportRule to keep the command multi-line and readable
$params = @{
    Name                                  = 'Limit Inbound Mail to AppRiver (Quarantine direct send)'
    Comments                              = 'This rule will quarantine incoming external email if the message was not delivered by ETP. This rule should only be active for ETP customers and it must be disabled if ETP service is cancelled.'
    SenderAddressLocation                 = 'Header'
    FromScope                             = 'NotInOrganization'
    Quarantine                            = $true
    SetSCL                                = 6
    ExceptIfSenderIpRanges                = $appRiverIPs
    Enabled                               = $true
    Priority                              = 0
    ExceptIfHeaderContainsMessageHeader   = 'x-ms-exchange-meetingforward-message'
    ExceptIfHeaderContainsWords           = 'Forward'
    ExceptIfMessageTypeMatches            = 'Voicemail'
}

New-TransportRule @params

# Reference: https://support.zixcorp.com/app/answers/detail/a_id/2933/kw/inbound%20route%20limit
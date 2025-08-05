# Description: This script creates a transport rule in Exchange Online to bypass spam filtering for emails coming from AppRiver IP ranges.

# Install Exchange Online module if not already installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
}

# Import the module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline

# Execute the transport rule command
New-TransportRule -Name "Bypass filtering for AppRiver" -SetSCL "-1" -SenderIpRanges 8.19.118.0/24,8.31.233.0/24,69.20.58.224/28,69.25.26.128/26,74.203.184.184/32,199.187.164.0/24,199.187.165.0/24,199.187.166.0/24,199.187.167.0/24,5.152.184.128/25,5.152.185.128/26,5.152.188.0/24 -Enabled $true -Priority 0

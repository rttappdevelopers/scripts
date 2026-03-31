# Required variables 
# VPN_Name                  vpnname                 String  Work
# VPN_Port                  vpnport                 String  443
# VPN_Host                  vpnhost                 String  Enter the VPN Host
# VPN_Use_SAML              vpnusesaml              Boolean False
# VPN_SAML_External_Browser vpnsamlexternalbrowser  Boolean False

# Required file
# FortiClientVPN.exe

# Get variables from Ninja RMM custom fields
$vpnname = Ninja-Property-Get vpnname
$vpnport = Ninja-Property-Get vpnport
$vpnhost = Ninja-Property-Get vpnhost
$vpnusesaml = Ninja-Property-Get vpnusesaml
$vpnsamlexternalbrowser = Ninja-Property-Get vpnsamlexternalbrowser

$VPNAddress = $vpnhost + ":" + $vpnport
$keyPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\" + $vpnname

# Check to see if a VPN connection already exists with this name, and recreate it with the new settings if it does
if ((Test-Path -LiteralPath $keyPath) -ne $true) {
    New-Item $keyPath -Force
} else {
    Remove-Item -LiteralPath $keyPath -Force
    New-Item $keyPath -Force
}

# Add the new settings to the registry for the VPN connection
New-ItemProperty -LiteralPath $keyPath -Name 'Description' -Value 'Connection Used for Work' -PropertyType String -Force
New-ItemProperty -LiteralPath $keyPath -Name 'Server' -Value $VPNAddress -PropertyType String -Force

New-ItemProperty -LiteralPath $keyPath -Name 'promptcertificate' -Value 0 -PropertyType DWord -Force
New-ItemProperty -LiteralPath $keyPath -Name 'ServerCert' -Value '0' -PropertyType String -Force

if ($vpnusesaml -eq 1) {
    if ($vpnsamlexternalbrowser -eq 1) {
        New-ItemProperty -LiteralPath $keyPath -Name 'use_external_browser' -Value 1 -PropertyType DWord -Force
    }

    New-ItemProperty -LiteralPath $keyPath -Name 'sso_enabled' -Value 1 -PropertyType DWord -Force
    New-ItemProperty -LiteralPath $keyPath -Name 'promptusername' -Value 0 -PropertyType DWord -Force
} else {
    New-ItemProperty -LiteralPath $keyPath -Name 'use_external_browser' -Value 0 -PropertyType DWord -Force
    New-ItemProperty -LiteralPath $keyPath -Name 'sso_enabled' -Value 0 -PropertyType DWord -Force
    New-ItemProperty -LiteralPath $keyPath -Name 'promptusername' -Value 1 -PropertyType DWord -Force
}


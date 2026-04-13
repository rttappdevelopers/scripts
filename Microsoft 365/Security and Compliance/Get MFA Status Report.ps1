#Requires -Version 7
<#
.SYNOPSIS
    Generates an MFA status report for all licensed Microsoft 365 users.

.DESCRIPTION
    Connects to Microsoft Graph and retrieves authentication methods for each
    user, producing a CSV report at C:\temp\MFAUsers.csv showing MFA state,
    default method, phone number, primary SMTP, and aliases.

.NOTES
    Name:    Get MFA Status Report
    Author:  RTT Support
    Context: Technician workstation (interactive)
#>

param()

$ErrorActionPreference = 'Stop'

# Ensure PowerShellGet is current enough to reliably install modules on older systems
try {
    $psGet = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
    if ($psGet.Version -lt [Version]'2.0') {
        Write-Host "Updating PowerShellGet before installing dependencies..."
        Install-Module -Name PowerShellGet -Scope CurrentUser -Force -AllowClobber
        throw "PowerShellGet updated. Please restart PowerShell and re-run this script."
    }
} catch {
    Write-Warning "Could not check/update PowerShellGet: $($_.Exception.Message)"
}

# Install and import the required Microsoft.Graph submodules
foreach ($mod in @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Identity.SignIns')) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "Installing $mod..."
        Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
}
try {
    Import-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns -ErrorAction Stop
} catch {
    throw "Failed to import Microsoft.Graph modules: $($_.Exception.Message)"
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes 'User.Read.All', 'UserAuthenticationMethod.Read.All', 'AuditLog.Read.All' -NoWelcome
} catch {
    throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
}

# Ensure output directory exists
if (-not (Test-Path 'c:\temp')) { New-Item -ItemType Directory -Path 'c:\temp' | Out-Null }

Write-Host "Finding user accounts..."
$Users = Get-MgUser -All -Filter "userType ne 'Guest'" -Property UserPrincipalName, DisplayName, ProxyAddresses, AssignedLicenses
$Report = [System.Collections.Generic.List[Object]]::new()
Write-Host "Processing $($Users.Count) accounts..."

ForEach ($User in $Users) {
    # Get authentication methods for this user
    $AuthMethods = Get-MgUserAuthenticationMethod -UserId $User.Id

    # Determine registered MFA methods
    $MethodTypes = $AuthMethods.AdditionalProperties.'@odata.type' | ForEach-Object { $_ -replace '#microsoft.graph.', '' }

    # Determine default/preferred MFA method (first non-password method found)
    $MFADefaultMethod = $MethodTypes | Where-Object { $_ -ne 'passwordAuthenticationMethod' } | Select-Object -First 1
    if ($MFADefaultMethod) {
        Switch ($MFADefaultMethod) {
            'phoneAuthenticationMethod'              { $MFADefaultMethod = 'Phone (SMS or call)' }
            'microsoftAuthenticatorAuthenticationMethod' { $MFADefaultMethod = 'Microsoft Authenticator app' }
            'softwareOathAuthenticationMethod'       { $MFADefaultMethod = 'Authenticator app or hardware token (OATH)' }
            'fido2AuthenticationMethod'              { $MFADefaultMethod = 'FIDO2 security key' }
            'windowsHelloForBusinessAuthenticationMethod' { $MFADefaultMethod = 'Windows Hello for Business' }
            'emailAuthenticationMethod'              { $MFADefaultMethod = 'Email OTP' }
            'temporaryAccessPassAuthenticationMethod' { $MFADefaultMethod = 'Temporary Access Pass' }
            default                                  { $MFADefaultMethod = $MFADefaultMethod }
        }
    } else {
        $MFADefaultMethod = 'Not enabled'
    }

    # MFA state: if any non-password method is registered, treat as enabled
    $MFAState = if ($MFADefaultMethod -ne 'Not enabled') { 'Enabled' } else { 'Disabled' }

    # Phone number (if phone method is registered)
    $PhoneMethod = $AuthMethods | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.phoneAuthenticationMethod' } | Select-Object -First 1
    $MFAPhoneNumber = $PhoneMethod.AdditionalProperties.phoneNumber

    $PrimarySMTP = $User.ProxyAddresses | Where-Object { $_ -clike 'SMTP:*' } | ForEach-Object { $_ -replace 'SMTP:', '' }
    $Aliases     = $User.ProxyAddresses | Where-Object { $_ -clike 'smtp:*' } | ForEach-Object { $_ -replace 'smtp:', '' }

    $ReportLine = [PSCustomObject]@{
        UserPrincipalName = $User.UserPrincipalName
        DisplayName       = $User.DisplayName
        MFAState          = $MFAState
        MFADefaultMethod  = $MFADefaultMethod
        MFAPhoneNumber    = $MFAPhoneNumber
        PrimarySMTP       = ($PrimarySMTP -join ',')
        Aliases           = ($Aliases -join ',')
    }

    $Report.Add($ReportLine)
}

Write-Host "Report is in c:\temp\MFAUsers.csv"
$Report | Select-Object UserPrincipalName, DisplayName, MFAState, MFADefaultMethod, MFAPhoneNumber, PrimarySMTP, Aliases | Sort-Object UserPrincipalName | Out-GridView
$Report | Sort-Object UserPrincipalName | Export-Csv -Encoding UTF8 -NoTypeInformation 'c:\temp\MFAUsers.csv'

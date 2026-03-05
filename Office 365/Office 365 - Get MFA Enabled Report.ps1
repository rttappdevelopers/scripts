# Get list view and CSV file of active users and their MFA status
# File export goes to "c:\temp\MFAUsers.csv"
# Note: MSOnline (MSOL) is end-of-life. This script uses Microsoft Graph instead.

# Ensure PowerShellGet is current enough to reliably install modules on older systems
try {
    $psGet = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
    if ($psGet.Version -lt [Version]'2.0') {
        Write-Host "Updating PowerShellGet before installing dependencies..."
        Install-Module -Name PowerShellGet -Scope CurrentUser -Force -AllowClobber
        Write-Host "PowerShellGet updated. Please restart PowerShell and re-run this script." -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Warning "Could not check/update PowerShellGet: $($_.Exception.Message)"
}

# Install and import the Microsoft.Graph module if not already present
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installing Microsoft.Graph module..."
    try {
        Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } catch {
        Write-Error "Failed to install Microsoft.Graph: $($_.Exception.Message)"
        exit 1
    }
}
try {
    Import-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns -ErrorAction Stop
} catch {
    Write-Error "Failed to import Microsoft.Graph modules: $($_.Exception.Message)"
    exit 1
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All", "AuditLog.Read.All" -NoWelcome -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
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
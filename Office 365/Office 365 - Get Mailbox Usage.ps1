<#
.SYNOPSIS
    Generates a comprehensive report of Microsoft 365 users, including their assigned licenses,
    last sign-in activity, security status, and organizational information.

.DESCRIPTION
    This script connects to Microsoft Graph API to gather
    comprehensive information about Microsoft 365 users in your tenant.
    It retrieves:
    - UserPrincipalName (UPN)
    - Display Name
    - Account Status (Enabled/Disabled)
    - User Type (Member/Guest)
    - Account Creation Date
    - Last Password Change
    - Assigned Licenses (friendly names)
    - Last Sign-in Date/Time
    - MFA Status
    - Group Membership Count
    - Admin Role Status
    - Mailbox Size and Item Count
    - OneDrive Used Storage

.NOTES
    Author: Brad Brown, with the help of GitHub Copilot
    Date: 2025-06-27
    Version: 2.0 - Switched to Microsoft Graph PowerShell SDK

.PREREQUISITES
    - PowerShell 5.1 or newer (PowerShell 7.x recommended)
    - Microsoft.Graph PowerShell module

    You can install this module using:
    Install-Module -Name Microsoft.Graph -Scope CurrentUser

.PERMISSIONS
    To run this script, the authenticated user (or app registration) requires
    the following Microsoft Graph API permissions:
    - User.Read.All
    - Directory.Read.All
    - AuditLog.Read.All
    - UserAuthenticationMethod.Read.All
    - GroupMember.Read.All
    - RoleManagement.Read.Directory
    - Mail.Read
    - Files.Read.All
#>

param(
    [string]$OutputPath = "$PSScriptRoot\M365_User_Report.csv"
)

# Module Installation Check and Import
function Install-AndImportModule {
    param(
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Module '$ModuleName' not found. Attempting to install..." -ForegroundColor Yellow
        try {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
            Write-Host "Module '$ModuleName' installed successfully." -ForegroundColor Green
            Import-Module -Name $ModuleName -Force | Out-Null
            Write-Host "Module '$ModuleName' imported." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install and import module '$ModuleName'. Please install it manually: Install-Module -Name $ModuleName -Scope CurrentUser -Force"
            exit 1
        }
    } else {
        Write-Host "Module '$ModuleName' found. Importing..." -ForegroundColor Green
        try {
            Import-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            Write-Warning "Failed to force import module '$ModuleName'. There might be existing conflicts. Error: $($_.Exception.Message)"
        }
        Write-Host "Module '$ModuleName' imported (or attempted)." -ForegroundColor Green
    }
}

Install-AndImportModule -ModuleName Microsoft.Graph
Install-AndImportModule -ModuleName ExchangeOnlineManagement

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan

# Define required Graph scopes (expanded for additional features)
$graphScopes = @(
    "User.Read.All",
    "Directory.Read.All",
    "AuditLog.Read.All",
    "UserAuthenticationMethod.Read.All",
    "GroupMember.Read.All",
    "RoleManagement.Read.Directory",
    "Mail.Read",
    "Files.Read.All"
)

try {
    Connect-MgGraph -Scopes $graphScopes -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Please ensure you have the necessary permissions and try again. Error: $($_.Exception.Message)"
    exit 1
}

Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
try {
    Connect-ExchangeOnline -ShowBanner:$false
    Write-Host "Successfully connected to Exchange Online." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Exchange Online. Error: $($_.Exception.Message)"
    Disconnect-MgGraph
    exit 1
}

Write-Host "Retrieving Microsoft 365 license SKUs for friendly names..." -ForegroundColor Cyan
$licenseSKUs = @{}
try {
    Get-MgSubscribedSku | ForEach-Object {
        $licenseSKUs[$_.SkuId] = $_.SkuPartNumber
    }
    Write-Host "Successfully retrieved license SKUs." -ForegroundColor Green
}
catch {
    Write-Warning "Could not retrieve license SKUs. License display might show GUIDs. Error: $($_.Exception.Message)"
}

# Get all Microsoft 365 Users with expanded properties
Write-Host "Retrieving all Microsoft 365 users..." -ForegroundColor Cyan
$users = @()
try {
    $users = Get-MgUser -All -Property @(
        "Id", "DisplayName", "UserPrincipalName", "AssignedLicenses", "Mail", "SignInActivity",
        "AccountEnabled", "UserType", "CreatedDateTime", "LastPasswordChangeDateTime"
    ) | Where-Object { $_.UserPrincipalName -ne $null }
    Write-Host "Found $($users.Count) users." -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve Microsoft 365 users from Graph. Error: $($_.Exception.Message)"
    exit 1
}

# Process User Data
Write-Host "Processing user data (licenses, last login, security status, etc.)..." -ForegroundColor Cyan
$reportData = @()
$progress = 0
$totalUsers = $users.Count

foreach ($user in $users) {
    $progress++
    Write-Progress -Activity "Gathering User Data" -Status "Processing user $($user.UserPrincipalName) ($progress of $totalUsers)" -PercentComplete (($progress / $totalUsers) * 100)

    $userPrincipalName = $user.UserPrincipalName
    $displayName = $user.DisplayName
    $userId = $user.Id

    # Basic Account Information
    $accountEnabled = $user.AccountEnabled
    $userType = $user.UserType ?? "Member"
    $createdDate = if ($user.CreatedDateTime) { $user.CreatedDateTime.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
    $lastPasswordChange = if ($user.LastPasswordChangeDateTime) { $user.LastPasswordChangeDateTime.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }

    # region Licenses
    $assignedLicenses = @()
    if ($user.AssignedLicenses -and $user.AssignedLicenses.Count -gt 0) {
        foreach ($license in $user.AssignedLicenses) {
            if ($licenseSKUs.ContainsKey($license.SkuId)) {
                $assignedLicenses += $licenseSKUs[$license.SkuId]
            } else {
                $assignedLicenses += $license.SkuId
            }
        }
    }
    $licensesString = if ($assignedLicenses.Count -gt 0) { $assignedLicenses -join "; " } else { "None" }
    
    # Last Login
    $lastSignIn = "N/A"
    try {
        if ($null -ne $user.SignInActivity -and $null -ne $user.SignInActivity.LastSignInDateTime) {
            $lastSignIn = $user.SignInActivity.LastSignInDateTime.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    catch {
        Write-Warning "Could not retrieve LastSignInDateTime for $($user.UserPrincipalName). Error: $($_.Exception.Message)"
    }

    # MFA Status
    $mfaStatus = "Unable to determine"
    try {
        $authMethods = Get-MgUserAuthenticationMethod -UserId $userId -ErrorAction SilentlyContinue
        if ($authMethods) {
            $strongMethods = $authMethods | Where-Object { 
                $_.AdditionalProperties.'@odata.type' -in @(
                    '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod',
                    '#microsoft.graph.phoneAuthenticationMethod',
                    '#microsoft.graph.fido2AuthenticationMethod'
                )
            }
            $mfaStatus = if ($strongMethods.Count -gt 0) { "Enabled" } else { "Disabled" }
        }
    }
    catch {
        $mfaStatus = "Unable to determine"
    }

    # Group Memberships Count
    $groupCount = "N/A"
    try {
        $userGroups = Get-MgUserMemberOf -UserId $userId -ErrorAction SilentlyContinue
        $groupCount = if ($userGroups) { $userGroups.Count } else { 0 }
    }
    catch {
        $groupCount = "Unable to determine"
    }

    # Admin Roles
    $hasAdminRoles = "No"
    try {
        $adminRoles = Get-MgUserDirectoryRole -UserId $userId -ErrorAction SilentlyContinue
        $hasAdminRoles = if ($adminRoles -and $adminRoles.Count -gt 0) { "Yes ($($adminRoles.Count) roles)" } else { "No" }
    }
    catch {
        $hasAdminRoles = "Unable to determine"
    }

    # Email Storage Information
    $emailSize = "N/A"
    $emailItemCount = "N/A"
    try {
        $mailboxStats = Get-EXOMailboxStatistics -Identity $userId -ErrorAction SilentlyContinue
        if ($mailboxStats) {
            if ($mailboxStats.TotalItemSize) {
                # Parse size string (format: "XX.XX GB (X,XXX,XXX bytes)")
                $sizeString = $mailboxStats.TotalItemSize.ToString()
                if ($sizeString -match '([\d.]+)\s+(MB|GB)') {
                    $sizeValue = [double]$matches[1]
                    $sizeUnit = $matches[2]
                    if ($sizeUnit -eq "MB") {
                        $emailSize = [math]::Round($sizeValue / 1024, 2).ToString() + " GB"
                    } else {
                        $emailSize = [math]::Round($sizeValue, 2).ToString() + " GB"
                    }
                }
            }
            $emailItemCount = if ($mailboxStats.ItemCount) { $mailboxStats.ItemCount } else { 0 }
        }
    }
    catch {
        # Silently continue if mailbox access fails
    }

    # OneDrive Storage
    $oneDriveUsed = "N/A"
    try {
        $oneDrive = Get-MgUserDrive -UserId $userId -ErrorAction SilentlyContinue
        if ($oneDrive -and $oneDrive.Quota) {
            $usedBytes = $oneDrive.Quota.Used
            if ($usedBytes -and $usedBytes -gt 0) {
                $oneDriveUsed = [math]::Round($usedBytes / 1GB, 2).ToString() + " GB"
            } else {
                $oneDriveUsed = "0 GB"
            }
        }
    }
    catch {
        $oneDriveUsed = "Unable to determine"
    }
    
    # Add data to the report
    $reportData += [PSCustomObject]@{
        UserPrincipalName     = $userPrincipalName
        DisplayName           = $displayName
        AccountEnabled        = $accountEnabled
        UserType              = $userType
        CreatedDate           = $createdDate
        LastPasswordChange    = $lastPasswordChange
        AssignedLicenses      = $licensesString
        LastSignInUTC         = $lastSignIn
        MFAStatus             = $mfaStatus
        GroupMemberships      = $groupCount
        HasAdminRoles         = $hasAdminRoles
        EmailMailboxSizeGB    = $emailSize
        EmailItemCount        = $emailItemCount
        OneDriveUsedGB        = $oneDriveUsed
    }
}

# Export Report
Write-Host "Exporting report to $($OutputPath)..." -ForegroundColor Cyan
try {
    $reportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report successfully exported to '$OutputPath'." -ForegroundColor Green
    Write-Host "Report contains $($reportData.Count) user records with the following columns:" -ForegroundColor Green
    Write-Host "- UserPrincipalName, DisplayName, AccountEnabled, UserType" -ForegroundColor Gray
    Write-Host "- CreatedDate, LastPasswordChange, AssignedLicenses, LastSignInUTC" -ForegroundColor Gray
    Write-Host "- MFAStatus, GroupMemberships, HasAdminRoles" -ForegroundColor Gray
    Write-Host "- EmailMailboxSizeGB, EmailItemCount, OneDriveUsedGB" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to export report to '$OutputPath'. Error: $($_.Exception.Message)"
}

# Disconnect
Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Cyan
try {
    Disconnect-MgGraph
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Warning "Failed to disconnect from Microsoft Graph cleanly."
}

Write-Host "Disconnecting from Exchange Online..." -ForegroundColor Cyan
try {
    Disconnect-ExchangeOnline -Confirm:$false
    Write-Host "Disconnected from Exchange Online." -ForegroundColor Green
}
catch {
    Write-Warning "Failed to disconnect from Exchange Online cleanly."
}

Write-Host "Script finished." -ForegroundColor Green

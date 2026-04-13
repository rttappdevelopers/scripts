<#
.SYNOPSIS
    Retrieves Immutable ID, creation date, and last directory sync time for all Microsoft 365 users.

.DESCRIPTION
    Uses Microsoft Graph to query all users and display their ImmutableId
    (OnPremisesImmutableId), account creation date, and last directory sync
    timestamp.  Results are displayed in a table and optionally exported to CSV.

    Replaces the legacy MSOnline (Get-MsolUser) version of this script.

.EXAMPLE
    .\"Office 365 - Get Immutable ID.ps1"

.NOTES
    Requires:  PowerShell 7+, Microsoft.Graph.Users module
    Auth:      Interactive browser-based sign-in (delegated)
    Permissions: User.Read.All (delegated)
#>
#Requires -Version 7
param()

$ErrorActionPreference = 'Stop'

# --- Module management --------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Host "Installing Microsoft.Graph.Users module (this may take a moment)..."
    Install-Module -Name Microsoft.Graph.Users -Force -AllowClobber -Scope CurrentUser
}
Import-Module Microsoft.Graph.Users -ErrorAction Stop

# --- Authentication (modern — interactive browser) ----------------------------
try {
    Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome
    Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
} catch {
    throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
}

# --- Data retrieval -----------------------------------------------------------
try {
    $users = Get-MgUser -All -Property UserPrincipalName, OnPremisesImmutableId, CreatedDateTime, OnPremisesLastSyncDateTime |
        Select-Object UserPrincipalName, OnPremisesImmutableId, CreatedDateTime, OnPremisesLastSyncDateTime

    if (-not $users) {
        Write-Warning "No users returned from Microsoft Graph."
    } else {
        $users | Format-Table -AutoSize
        Write-Host "Total users: $($users.Count)" -ForegroundColor Cyan

        # Uncomment the next line to export to CSV:
        # $users | Export-Csv -Path "$HOME\Desktop\ImmutableIDs.csv" -NoTypeInformation -Encoding UTF8
    }
} catch {
    throw "Failed to retrieve users: $($_.Exception.Message)"
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

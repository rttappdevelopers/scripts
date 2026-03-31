<#
.SYNOPSIS
    Finds Windows services running under non-system user accounts.

.DESCRIPTION
    Searches for Windows services running as user accounts (not LocalSystem,
    LocalService, or NetworkService). Optionally filters by a search term to
    find services running as a specific account.

    Results are output to stdout and optionally written to a NinjaOne custom field.

    Replaces the former 'Check for services running as admin.ps1' (CentraStage)
    and 'Services Running As.ps1' scripts, consolidated and modernized to use
    Get-CimInstance instead of deprecated Get-WmiObject.

.PARAMETER SearchTerm
    Optional. Substring to match against the service StartName (logon account).
    If not provided, returns all services running as non-system accounts.

.PARAMETER CustomFieldName
    Optional. NinjaOne custom field name to write results to. Defaults to
    $env:CustomFieldName or 'servicesRunningAs'.

.EXAMPLE
    .\Services Running As.ps1
    Lists all services running as non-system user accounts.

.EXAMPLE
    .\Services Running As.ps1 -SearchTerm "admin"
    Lists services running as accounts containing "admin".

.NOTES
    Author:         RTT (Round Table Technology)
    Created:        2026-03-31
    Replaces:       Check for services running as admin.ps1, Services Running As.ps1
    RMM Compatible: Yes — runs silently at SYSTEM level
#>

param(
    [string]$SearchTerm,
    [string]$CustomFieldName
)

$ProgressPreference = "SilentlyContinue"

# NinjaOne environment variable overrides
if (-not $SearchTerm -and $env:searchterm) { $SearchTerm = $env:searchterm }
if (-not $CustomFieldName -and $env:CustomFieldName) { $CustomFieldName = $env:CustomFieldName }
if (-not $CustomFieldName) { $CustomFieldName = "servicesRunningAs" }

# System accounts to exclude when no search term is specified
$SystemAccounts = @("LocalSystem", "NT Authority\LocalService", "NT AUTHORITY\LocalService",
                     "NT Authority\NetworkService", "NT AUTHORITY\NetworkService")

try {
    if ($SearchTerm) {
        Write-Output "Checking for services running as accounts containing: $SearchTerm"
        $results = Get-CimInstance -ClassName Win32_Service |
            Where-Object { $_.StartName -match $SearchTerm } |
            Select-Object DisplayName, StartName, State
    }
    else {
        Write-Output "Checking for services running as non-system user accounts..."
        $results = Get-CimInstance -ClassName Win32_Service |
            Where-Object { $_.StartName -and $_.StartName -notin $SystemAccounts -and $_.State -eq "Running" } |
            Select-Object DisplayName, StartName, State
    }
}
catch {
    Write-Error "Failed to query services: $($_.Exception.Message)"
    exit 1
}

if ($results -and $results.Count -gt 0) {
    $output = $results | Format-Table -AutoSize | Out-String
    Write-Output $output
    Write-Output "Total: $($results.Count) service(s) found."

    # Write to NinjaOne custom field
    try {
        Ninja-Property-Set $CustomFieldName ($results | Format-Table -AutoSize -HideTableHeaders | Out-String).Trim()
    }
    catch {
        # Not running in NinjaOne — silently ignore
    }
}
else {
    Write-Output "No matching services found."
    try { Ninja-Property-Set $CustomFieldName "None" } catch { }
}

exit 0

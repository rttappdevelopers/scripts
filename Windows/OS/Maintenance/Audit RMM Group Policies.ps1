<#
.SYNOPSIS
    Audits and optionally removes RMM-related Group Policy Objects (GPOs).

.DESCRIPTION
    Searches Active Directory for GPOs with names matching common RMM deployment
    patterns (AEM, RMM, CAG, Datto, CentraStage, NinjaOne, Ninja). Lists all
    matching GPOs with their enabled/disabled status.

    By default, this script only REPORTS — it does not delete anything.
    To remove GPOs, you must explicitly pass -Remove. Even then, each GPO
    requires confirmation unless -Force is also specified.

    Results are output to stdout (captured by NinjaOne) and optionally written
    to a NinjaOne custom field.

    Replaces the former 'Get-RMM_GPo.ps1' and 'RMM Agent Deployment GPO Audit.ps1'
    scripts which had CentraStage references and unsafe deletion behavior.

.PARAMETER Remove
    If specified, removes matching GPOs after listing them. Requires confirmation
    for each GPO unless -Force is also specified.

.PARAMETER Force
    Suppresses per-GPO confirmation prompts when used with -Remove.
    Use with extreme caution.

.PARAMETER SearchTerms
    Optional. Array of search terms to match GPO names. Defaults to common RMM
    deployment patterns: AEM, RMM, CAG, Datto, CentraStage, NinjaOne, Ninja.

.PARAMETER CustomFieldName
    Optional. NinjaOne custom field name to write results to. If not specified,
    checks $env:CustomFieldName. If neither is set, results are only written to stdout.

.EXAMPLE
    .\RMM GPO Audit and Cleanup.ps1
    Lists all RMM-related GPOs without removing any.

.EXAMPLE
    .\RMM GPO Audit and Cleanup.ps1 -Remove
    Lists and removes RMM-related GPOs with per-GPO confirmation prompts.

.EXAMPLE
    .\RMM GPO Audit and Cleanup.ps1 -Remove -Force
    Lists and removes all matching GPOs without confirmation. Use with caution.

.NOTES
    Author:         RTT (Round Table Technology)
    Created:        2026-03-31
    Replaces:       Get-RMM_GPo.ps1, RMM Agent Deployment GPO Audit.ps1
    Requirements:   GroupPolicy module (RSAT), Run as Administrator
    RMM Compatible: Yes — runs silently at SYSTEM level (audit mode only)
#>

param(
    [switch]$Remove,
    [switch]$Force,
    [string[]]$SearchTerms = @("AEM", "RMM", "CAG", "Datto", "CentraStage", "NinjaOne", "Ninja"),
    [string]$CustomFieldName
)

$ProgressPreference = "SilentlyContinue"

# NinjaOne environment variable override
if (-not $CustomFieldName -and $env:CustomFieldName) {
    $CustomFieldName = $env:CustomFieldName
}

# --- Module check ---
try {
    Import-Module GroupPolicy -ErrorAction Stop
}
catch {
    Write-Error "GroupPolicy module is not available. Install RSAT or run on a domain controller."
    exit 1
}

# --- Build filter ---
$filterParts = $SearchTerms | ForEach-Object { "`$_.DisplayName -like '*$_*'" }
$filterScript = [scriptblock]::Create($filterParts -join ' -or ')

# --- Audit ---
try {
    $gpos = Get-GPO -All | Where-Object -FilterScript $filterScript |
        Select-Object DisplayName, Id, @{Name = "Status"; Expression = { $_.GpoStatus } }
}
catch {
    Write-Error "Failed to query GPOs: $($_.Exception.Message)"
    exit 1
}

if (-not $gpos -or $gpos.Count -eq 0) {
    Write-Output "No GPOs found matching search terms: $($SearchTerms -join ', ')"
    if ($CustomFieldName) {
        try { Ninja-Property-Set $CustomFieldName "None found" } catch { }
    }
    exit 0
}

Write-Output "=== RMM-Related GPOs Found ==="
$gpos | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "Total: $($gpos.Count) GPO(s) found."

# --- Write to NinjaOne custom field ---
if ($CustomFieldName) {
    $csv = ($gpos | ConvertTo-Csv -NoTypeInformation) -join "`n"
    try {
        Ninja-Property-Set $CustomFieldName $csv
        Write-Output "Results written to NinjaOne custom field: $CustomFieldName"
    }
    catch {
        Write-Warning "Failed to write to NinjaOne custom field '$CustomFieldName': $($_.Exception.Message)"
    }
}

# --- Remove (only if explicitly requested) ---
if ($Remove) {
    Write-Output ""
    Write-Output "=== GPO Removal ==="

    foreach ($gpo in $gpos) {
        if (-not $Force) {
            $confirm = Read-Host "Remove GPO '$($gpo.DisplayName)' (ID: $($gpo.Id))? [y/N]"
            if ($confirm -notin @("y", "yes")) {
                Write-Output "  Skipped: $($gpo.DisplayName)"
                continue
            }
        }

        try {
            Remove-GPO -Guid $gpo.Id -Confirm:$false -ErrorAction Stop
            Write-Output "  Removed: $($gpo.DisplayName)"
        }
        catch {
            Write-Warning "  Failed to remove '$($gpo.DisplayName)': $($_.Exception.Message)"
        }
    }

    Write-Output "GPO removal complete."
}
else {
    Write-Output ""
    Write-Output "Audit mode only — no GPOs were removed. Use -Remove to delete matching GPOs."
}

exit 0

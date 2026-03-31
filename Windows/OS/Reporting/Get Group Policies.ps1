<#
.SYNOPSIS
    Lists all Group Policy Objects (GPOs) in the domain.

.DESCRIPTION
    This script retrieves and displays all Group Policy Objects from Active Directory,
    including their name, GUID, creation date, modification date, and GPO status.

.EXAMPLE
    .\Get Group Policies.ps1
#>

# Requires the GroupPolicy module
Import-Module GroupPolicy -ErrorAction Stop

try {
    Write-Host "Retrieving all Group Policy Objects..." -ForegroundColor Cyan
    
    # Get all GPOs in the domain
    $GPOs = Get-GPO -All | Sort-Object DisplayName
    
    # Display summary
    Write-Host "`nTotal GPOs found: $($GPOs.Count)" -ForegroundColor Green
    Write-Host ("-" * 100) -ForegroundColor Gray
    
    # Display GPO details
    $GPOs | Format-Table -AutoSize `
        DisplayName,
        @{Label="GUID"; Expression={$_.Id}},
        @{Label="Created"; Expression={$_.CreationTime.ToString("yyyy-MM-dd")}},
        @{Label="Modified"; Expression={$_.ModificationTime.ToString("yyyy-MM-dd")}},
        @{Label="Status"; Expression={$_.GpoStatus}}
    
    # Export to CSV option
    $export = Read-Host "`nWould you like to export this to CSV? (Y/N)"
    if ($export -eq 'Y' -or $export -eq 'y') {
        $csvPath = "$PSScriptRoot\GroupPolicies_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $GPOs | Select-Object DisplayName, Id, DomainName, CreationTime, ModificationTime, GpoStatus |
            Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Exported to: $csvPath" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to retrieve Group Policies: $_"
    Write-Host "Note: This script requires the GroupPolicy module and appropriate permissions." -ForegroundColor Yellow
}
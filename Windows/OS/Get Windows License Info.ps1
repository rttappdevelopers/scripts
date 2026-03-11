<#
.SYNOPSIS
    Audits Windows volume license activation status on the system.

.DESCRIPTION
    Queries the SoftwareLicensingProduct WMI class to report the Windows activation
    status, license channel (Volume/Retail/OEM), partial product key, and KMS server
    (if applicable). This is the correct way to verify that a Volume License Key (VLK)
    was successfully applied and activated across a fleet.

    Results are written to console output and published to the Ninja RMM custom field
    'windowsLicenseKey'.

.EXAMPLE
    .\Get Windows License Key.ps1
    Outputs activation status and license info to console and Ninja RMM if available.

.NOTES
    Author: Brad Brown
    Requires: PowerShell 5.1+, Administrative privileges
    Runs as: SYSTEM level (via RMM)
    Output: Activation summary to stdout, and to Ninja RMM windowsLicenseKey field

    Note: Volume License Keys (KMS/MAK) do not expose the full key after application.
    The partial key (last 5 chars) and activation status are the correct indicators
    that a VLK was successfully applied.
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# LicenseStatus code to human-readable string
function Get-LicenseStatusText {
    param([int]$StatusCode)
    switch ($StatusCode) {
        0 { return "Unlicensed" }
        1 { return "Licensed" }
        2 { return "OOBGrace (Out-of-Box Grace Period)" }
        3 { return "OOTGrace (Out-of-Tolerance Grace Period)" }
        4 { return "NonGenuineGrace" }
        5 { return "Notification" }
        6 { return "ExtendedGrace" }
        default { return "Unknown ($StatusCode)" }
    }
}

# Main execution
try {
    # Filter at the WMI query level to avoid enumerating hundreds of licensing rows.
    # ApplicationId 55c92734-d682-4d71-983e-d6ec3f16059f is the Windows OS licensing application.
    # PartialProductKey being non-null means a key is actually installed (not just a placeholder).
    $product = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop `
        -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" |
        Select-Object -First 1

    if (-not $product) {
        Write-Host "No active Windows licensing product found."
        exit 1
    }

    $statusText    = Get-LicenseStatusText -StatusCode $product.LicenseStatus
    $partialKey    = $product.PartialProductKey
    $licenseFamily = if ($product.LicenseFamily) { $product.LicenseFamily } else { "N/A (Retail/OEM)" }
    $channel       = if ($product.LicenseFamily -match "\S") { "Volume" } else { "Retail / OEM" }
    $kmsServer     = if ($product.DiscoveredKeyManagementServiceMachineName) {
                         "$($product.DiscoveredKeyManagementServiceMachineName):$($product.DiscoveredKeyManagementServiceMachinePort)"
                     } else { "N/A" }
    $productName   = $product.Name

    # Build summary output
    $summary = @(
        "Product      : $productName"
        "Channel      : $channel"
        "License Type : $licenseFamily"
        "Partial Key  : $partialKey"
        "Status       : $statusText"
        "KMS Server   : $kmsServer"
    ) -join " | "

    Write-Host "Windows Activation Status"
    Write-Host "  Product      : $productName"
    Write-Host "  Channel      : $channel"
    Write-Host "  License Type : $licenseFamily"
    Write-Host "  Partial Key  : *****-$partialKey"
    Write-Host "  Status       : $statusText"
    Write-Host "  KMS Server   : $kmsServer"

    # Publish to Ninja RMM custom field
    if (Get-Command "Ninja-Property-Set" -ErrorAction SilentlyContinue) {
        try {
            Ninja-Property-Set windowsLicenseKey $summary
            Write-Host "Successfully published to Ninja RMM custom field 'windowsLicenseKey'"
        }
        catch {
            Write-Warning "Failed to set Ninja RMM field: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "Ninja RMM command not available - skipping field update"
    }

    # Exit non-zero if not licensed
    if ($product.LicenseStatus -ne 1) {
        Write-Warning "System is NOT fully licensed (Status: $statusText)"
        exit 1
    }

    exit 0
}
catch {
    Write-Error "Script error: $($_.Exception.Message)"
    exit 1
}

<#
.SYNOPSIS
    Deletes a local user account and its profile folder from a Windows endpoint.

.DESCRIPTION
    Reads the target username from the RMM environment variable 'useracct'.
    Accepts plain usernames (e.g. jsmith) or domain-prefixed formats (e.g. AzureAD\jsmith,
    DOMAIN\jsmith). The domain prefix is stripped before matching.

    If a local account matching the username exists, it is removed via Remove-LocalUser.
    AzureAD-joined accounts do not have a local account entry - this is expected and the
    script continues to profile deletion regardless.

    The profile folder (C:\Users\<username>) is then deleted if it exists.

.PARAMETER useracct
    Set via the 'useracct' Ninja environment variable. Accepts plain or domain-prefixed usernames.

.PARAMETER Reboot
    If specified, the system will reboot after the profile is successfully deleted.
    Can also be set via the 'reboot' Ninja environment variable (true/1).

.EXAMPLE
    $env:useracct = "jsmith"
    .\Delete User Profile.ps1

.EXAMPLE
    $env:useracct = "AzureAD\jsmith"
    .\Delete User Profile.ps1

.NOTES
    Deployed via NinjaOne RMM. Runs at SYSTEM level with no interactive UI.
#>

#Requires -RunAsAdministrator

param(
    [switch]$Reboot
)

$ProgressPreference = "SilentlyContinue"

# Ninja environment variable override
if ($env:reboot -in @("true", "1")) { $Reboot = $true }

# Make sure environment variable "useracct" is set
if ($null -eq $env:useracct -or $env:useracct -eq "") {
    Write-Output "Environment variable 'useracct' not set, exiting."
    exit 1
}

# Strip domain prefix (e.g. AzureAD\username or DOMAIN\username -> username)
$raw = $env:useracct
$useracct = if ($raw -match '\\') { $raw.Split('\')[-1] } else { $raw }
Write-Output "Target username: $useracct"

# Check for a local account and delete it if found.
# AzureAD-joined accounts have no local account entry - this is normal; continue either way.
$localAccount = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount=True" |
    Where-Object { $_.Name -eq $useracct }

if ($localAccount) {
    Write-Output "Local account found, deleting."
    Remove-LocalUser -Name $useracct
} else {
    Write-Output "No local account found for '$useracct' (may be an AzureAD account - continuing)."
}

# Terminate all processes running under the target user to release file locks
Write-Output "Terminating processes for '$useracct'..."
& taskkill /F /FI "USERNAME eq $useracct" /T 2>&1 | ForEach-Object { Write-Output $_ }

# Stop the Connected Devices Platform user service, which holds ActivitiesCache.db locks
Get-Service -Name "CDPUserSvc_*" -ErrorAction SilentlyContinue |
    Stop-Service -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# Delete the profile folder if it exists
if (Test-Path "C:\Users\$useracct") {
    Write-Output "User profile folder found, deleting."
    Remove-Item -Recurse -Force "C:\Users\$useracct" -ErrorAction SilentlyContinue

    # Verify deletion succeeded
    if (Test-Path "C:\Users\$useracct") {
        Write-Output "WARNING: Profile folder could not be fully removed. Some files may still be locked."
        Write-Output "Remaining items:"
        Get-ChildItem -Recurse "C:\Users\$useracct" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName | ForEach-Object { Write-Output "  $_" }
    } else {
        Write-Output "Profile folder deleted."
    }
} else {
    Write-Output "User profile folder 'C:\Users\$useracct' not found."
    exit 1
}

if ($Reboot) {
    Write-Output "Reboot requested - restarting now."
    Restart-Computer -Force
}

exit 0

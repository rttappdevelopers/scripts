#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates or resets the client administrative local user account.

.DESCRIPTION
    Reads the local admin username and password from NinjaOne org-level custom fields
    (injected as environment variables). Creates the account if it does not exist, or
    resets its password if it does. Ensures the account is a member of the local
    Administrators group.

.NOTES
    Org custom fields required (NinjaOne - Organization level):
        clientAdminName  - Text field: local account username (max 20 chars)
        clientAdminPw    - Secure field: local account password

    Uses Get-NinjaProperty (NinjaOne PowerShell module, deployed with agent) to read
    org-level custom fields. $env: variables are NOT used - org fields are not auto-injected
    as environment variables; they must be read via the CLI module.

    Designed for RMM deployment at SYSTEM level. No interactive prompts.
    Exit 0 = success, Exit 1 = failure.
#>

param()

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Stop"

# The NinjaOne PS module (Get-NinjaProperty) calls ninjarmm-cli.exe by name and requires
# it to be on PATH. At SYSTEM level the NinjaRMMAgent directory is not on PATH.
# $env:NINJARMMCLI is a machine-level env var set by the agent pointing to the full exe path.
# We trust it directly rather than doing file-system checks (which fail on this protected dir).
if ($env:NINJARMMCLI) {
    $ninjaCliDir = Split-Path $env:NINJARMMCLI -Parent
    Write-Host "Adding NinjaOne CLI directory to PATH: $ninjaCliDir"
    if ($env:Path -notlike "*$ninjaCliDir*") {
        $env:Path = "$ninjaCliDir;$env:Path"
    }
} else {
    Write-Error "NINJARMMCLI environment variable is not set. Is the NinjaOne agent installed?"
    exit 1
}

# Read org-level custom fields via the NinjaOne PowerShell module.
# Get-NinjaProperty supports secure field access during automation execution.
# $env: variables do NOT work for org custom fields - they must be read via the CLI module.
try {
    $username = Get-NinjaProperty -Name "clientAdminName"
    $password = Get-NinjaProperty -Name "clientAdminPw" -Type Secure
} catch {
    Write-Error "Failed to read NinjaOne custom fields: $($_.Exception.Message)"
    exit 1
}

# Validate that both values were returned
if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)) {
    Write-Error "clientAdminName or clientAdminPw org field is not set. Cancelling."
    exit 1
}

# Enforce Windows 20-character username limit
if ($username.Length -gt 20) {
    Write-Error "Username '$username' is $($username.Length) characters, which exceeds the Windows 20-character limit."
    exit 1
}

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

try {
    Get-LocalUser -Name $username -ErrorAction Stop
    Write-Host "User account '$username' already exists. Resetting password..."
    Set-LocalUser -Name $username -Password $securePassword
    Write-Host "Password updated successfully."
}
catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
    Write-Host "User account '$username' does not exist. Creating it..."
    New-LocalUser -Name $username -Password $securePassword -PasswordNeverExpires:$true
    Write-Host "User account '$username' created successfully."
}
catch {
    Write-Error "Failed to create or update user account: $($_.Exception.Message)"
    exit 1
}

# Ensure the account is in the Administrators group
try {
    Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction Stop
    Write-Host "$username has been added to the Administrators group."
}
catch [Microsoft.PowerShell.Commands.MemberExistsException] {
    Write-Host "$username is already a member of Administrators."
}
catch {
    Write-Error "Failed to add '$username' to Administrators: $($_.Exception.Message)"
    exit 1
}

exit 0
#Requires -Version 5.1

<#
.SYNOPSIS
    Create a local user account with options to enable and disable at specific dates, and add to local admin group. Saves randomly generated password to a custom field.
.DESCRIPTION
    You can specify when the account will be enabled and/or disabled.
    You can have the account be added as a member of the local Administrators group.

PARAMETER: -UserNameToAdd "JohnTSmith" -Name "John T Smith"
    Create use with the name JohnTSmith and display name of John T Smith.
.EXAMPLE
    -UserNameToAdd "JohnTSmith" -Name "John T Smith"
    ## EXAMPLE OUTPUT ##
    User JohnTSmith has been created successfully.
    User JohnTSmith was added to the local Users group.

PARAMETER: -UserNameToAdd "JohnTSmith" -Name "John T Smith" -DateAndTimeToEnable "Monday, January 1, 2020 1:00:00 PM"
    Create use with the name JohnTSmith and display name of John T Smith.
    The user will start out disabled.
    A scheduled task will be create to enable the user after "Monday, January 1, 2020 1:00:00 PM"
.EXAMPLE
    -UserNameToAdd "JohnTSmith" -Name "John T Smith" -DateAndTimeToEnable "Monday, January 1, 2020 1:00:00 PM"
    ## EXAMPLE OUTPUT ##
    User JohnTSmith has been created successfully.
    User JohnTSmith was added to the local Users group.
    Created Scheduled Task: Enable User JohnTSmith
    User JohnTSmith will be able to login after Monday, January 1, 2020 1:00:00 PM.

PARAMETER: -UserNameToAdd "JohnTSmith" -Name "John T Smith" -DisableAfterDays 10
    Create use with the name JohnTSmith and display name of John T Smith.
    The user will be disabled after 10 days after the user's creation.
.EXAMPLE
    -UserNameToAdd "JohnTSmith" -Name "John T Smith" -DisableAfterDays 10
    ## EXAMPLE OUTPUT ##
    User JohnTSmith has been created successfully.
    User JohnTSmith was added to the local Users group.

PARAMETER: -UserNameToAdd "JohnTSmith" -Name "John T Smith" -AddToLocalAdminGroup
    Create use with the name JohnTSmith and display name of John T Smith.
    User will be added as a member of the local Administrators group.
.EXAMPLE
    -UserNameToAdd "JohnTSmith" -Name "John T Smith" -AddToLocalAdminGroup
    ## EXAMPLE OUTPUT ##
    User JohnTSmith has been created successfully.
    User JohnTSmith was added to the local Users group.
    User JohnTSmith was added to the local Administrators group.
.OUTPUTS
    None
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes: Initial Release
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$UserNameToAdd,
    [Parameter()]
    [String]$Name,
    [Parameter()]
    [String]$PasswordCustomField,
    [Parameter()]
    [int]$PasswordLength,
    [Parameter()]
    [DateTime]$DateAndTimeToEnable,
    [Parameter()]
    [int]$DisableAfterDays,
    [Parameter()]
    [Switch]$AddToLocalAdminGroup,
    [Parameter()]
    $PasswordOptions
)

begin {
    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    function New-SecurePassword {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [int]$Length = 16,
            [Parameter(Mandatory = $false)]
            [bool]$IncludeSpecialCharacters = $true
        )
        # .NET class for generating cryptographically secure random numbers
        $cryptoProvider = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $SpecialCharacters = if ($IncludeSpecialCharacters) { '!@#$%&-' }
        $passwordChars = "abcdefghjknpqrstuvwxyzABCDEFGHIJKMNPQRSTUVWXYZ0123456789$SpecialCharacters"
        $password = for ($i = 0; $i -lt $Length; $i++) {
            $byte = [byte[]]::new(1)
            $cryptoProvider.GetBytes($byte)
            $charIndex = $byte[0] % $passwordChars.Length
            $passwordChars[$charIndex]
        }
        return $password -join ''
    }
    function New-LocalUserFromNinja {
        param(
            [string]$Username,
            [string]$Name,
            [string]$PasswordCustomField,
            [DateTime]$EnableDate,
            [int]$DisableAfterDays,
            [switch]$AddToLocalAdminGroup
        )
        # Generate a secure localUserPassword
        $Password = New-SecurePassword -Length $PasswordLength -IncludeSpecialCharacters $true
        if ($Username -and $Name) {
            # Check if the user already exists
            if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
                # Create new local user
                $UserSplat = @{
                    Name                 = "$Username"
                    FullName             = "$Name"
                    Password             = ConvertTo-SecureString -String $($Password -join '') -AsPlainText -Force
                    Description          = "User account created on $(Get-Date)"
                    PasswordNeverExpires = $false
                }

                if ($EnableDate -and $EnableDate -gt (Get-Date)) {
                    $UserSplat['Disabled'] = $true
                }

                if (-not $EnableDate -and $DisableAfterDays) {
                    $UserSplat['AccountExpires'] = $(Get-Date).AddDays($DisableAfterDays)
                }
                elseif ($DisableAfterDays) {
                    $UserSplat['AccountExpires'] = $(Get-Date $EnableDate).AddDays($DisableAfterDays)
                }

                if ($env:passwordOptions -like 'Password Never Expires' -or $PasswordOptions -like 'Password Never Expires') {
                    $UserSplat['PasswordNeverExpires'] = $true
                }

                New-LocalUser @UserSplat
                if ($env:passwordOptions -like 'User Must Change Password' -or $PasswordOptions -like 'User Must Change Password') {
                    net.exe user $Username /logonpasswordchg:yes
                }
                # Write it to a secure custom field
                if ((Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
                    Write-Host "User $Username has been created successfully."
                    if ($PasswordCustomField -like "null") {
                        Write-Host "CustomField not specified."
                        Write-Host "Password set to: $Password"
                    }
                    else {
                        Ninja-Property-Set -Name "$PasswordCustomField" -Value "$Password"
                        Write-Host "Password saved to $PasswordCustomField Custom Field."
                    }
                }
                else {
                    throw "Failed to create User $Username."
                }

                Add-LocalGroupMember -Group $(Get-LocalGroup -Name "Users") -Member $Username

                Write-Host "User $UserName was added to the local Users group."

                # If date to enable account is specified, disable account until then
                if ($EnableDate) {
                    if ($EnableDate -gt (Get-Date)) {
                        # Schedule a job to enable the user at the specified date
                        $TaskSplat = @{
                            Description = "Ninja Automation Enable User $Username"
                            Action      = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command & {Enable-LocalUser -Name `"$Username`"}"
                            Trigger     = New-ScheduledTaskTrigger -Once -At $EnableDate
                            Principal   = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
                        }

                        try {
                            New-ScheduledTask @TaskSplat | Register-ScheduledTask -User "System" -TaskName "Enable User $Username" | Out-Null
                            if ($(Get-ScheduledTask -TaskName "Enable User $Username")) {
                                Write-Host "Created Scheduled Task: Enable User $Username"
                            }
                            else {
                                throw "Failed to find scheduled task with the name 'Enable User $Username'"
                            }
                        }
                        catch {
                            Write-Error $_
                            throw "Failed to create Enable User scheduled task."
                        }

                        Write-Host "User $Username will be able to login after $EnableDate."
                    }
                }
                else {
                    Write-Host "No Enable Date is Set, $UserName is able to login now."
                }

                # Add to local admin group if specified
                if ($AddToLocalAdminGroup) {
                    Add-LocalGroupMember -Group $(Get-LocalGroup -Name "Administrators") -Member $Username
                    if (-not (Get-LocalGroupMember -Group $(Get-LocalGroup -Name "Administrators") -Member $Username)) {
                        throw "Failed to add user to local Administrators group."
                    }
                    Write-Host "User $UserName was added to the local Administrators group."
                }
            }
            else {
                Write-Host "User $Username already exists."
            }
        }
        else {
            throw "Username and Name are required to create a local account."
        }
    }
}
process {
    if ($env:usernameToAdd -and $env:usernameToAdd -like "null") {
        Write-Error "usernameToAdd($env:usernameToAdd) parameter is invalid."
        exit 1
    }
    if ($env:name -and $env:name -like "null") {
        Write-Error "name($env:name) parameter is invalid."
        exit 1
    }
    if ($env:passwordCustomField -and $env:passwordCustomField -like "null") {
        Write-Error "passwordCustomField($env:passwordCustomField) parameter is invalid."
        exit 1
    }
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }
    $params = @{
        Username = if ($PSBoundParameters.ContainsKey("UserNameToAdd")) { $UserNameToAdd }else { $env:usernameToAdd }
        Name     = if ($PSBoundParameters.ContainsKey("Name")) { $Name }else { $env:name }
    }
    # Conditionally add EnableDate
    if ($env:dateAndTimeToEnable -and $env:dateAndTimeToEnable -notlike "null") {
        $params["EnableDate"] = Get-Date "$env:dateAndTimeToEnable"
    }
    elseif ($PSBoundParameters.ContainsKey("DateAndTimeToEnable") -and $DateAndTimeToEnable) {
        $params["EnableDate"] = $DateAndTimeToEnable
    }
    # Conditionally add DisableAfterDays
    if ($env:disableAfterDays -notlike "null") {
        $params["DisableAfterDays"] = $env:disableAfterDays
    }
    elseif ($PSBoundParameters.ContainsKey("DisableAfterDays")) {
        $params["DisableAfterDays"] = $DisableAfterDays
    }

    # Conditionally add AddToLocalAdminGroup
    if ([Convert]::ToBoolean($env:addToLocalAdminGroup)) {
        $params["AddToLocalAdminGroup"] = $true
    }
    elseif ($PSBoundParameters.ContainsKey("AddToLocalAdminGroup")) {
        $params["AddToLocalAdminGroup"] = $AddToLocalAdminGroup
    }
    # Conditionally add AddToLocalAdminGroup
    if ($env:passwordCustomField -notlike "null") {
        $params["PasswordCustomField"] = $env:passwordCustomField
    }
    elseif ($env:passwordCustomField -like "null") {
        Write-Error "passwordCustomField: is Required"
        exit 1
    }
    elseif ($PSBoundParameters.ContainsKey("PasswordCustomField")) {
        $params["PasswordCustomField"] = $PasswordCustomField
    }

    if ($env:passwordLength -notlike "null") {
        $PasswordLength = $env:passwordLength
    }
    elseif (-not $passwordLength) {
        $PasswordLength = 20
    }

    try {
        New-LocalUserFromNinja @params
    }
    catch {
        Write-Error $_
        exit 1
    }
}
end {
        
}

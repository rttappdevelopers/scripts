#Requires -Version 7
<#
.SYNOPSIS
    Exports Exchange Online mailbox data to a CSV formatted for AppRiver user import.

.DESCRIPTION
    Connects to Exchange Online, retrieves all user mailboxes with their primary
    SMTP address and aliases, generates random passwords, and exports the data
    in the CSV format required by AppRiver for bulk user onboarding.

.NOTES
    Name:    Import AppRiver Users
    Author:  RTT Support
    Context: Technician workstation (interactive)
#>

param()

# Settings
# Replace these variables as needed, to affect all users created in AppRiver
$zix_Services = "Spam"       # Enter service to subscribe users to
$zix_welcomemail = "TRUE"    # Send welcome email to new users: TRUE or FALSE
$zix_culture = "English-us"  # What language will all users most?
$zix_geolocation = "US"      # What country code do users generally reside in?

# Where do you want the resulting file?
$exportpath = "C:\temp\"
$filename = "AppRiver-UserImport_Template.csv"

If (-not (Test-Path $exportpath)) { New-Item -Path $exportpath -Type Directory }
$exportpath = $exportpath + $filename
$exportpath

# Connect to Exchange Online
Write-Output "Connecting to Exchange Online `n"
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop
# -DisableWAM bypasses Web Account Manager to fix sign-in errors in elevated/non-standard terminals (e.g. running from C:\WINDOWS\system32).
Connect-ExchangeOnline -DisableWAM

Function New-SecurePassword {
$zix_password = "!?@#$%^&*123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray()
($zix_password | Get-Random -Count 20) -Join ''
}

# Begin operations
Write-Output "Pulling data from Exchange Online mailboxes. `n"
$userlist = Get-EXOMailbox -RecipientTypeDetails UserMailbox -ResultSize unlimited | 
            Select-Object   @{n="FirstName";e={(Get-User $_.Alias).FirstName}},
                            @{n="LastName";e={(Get-User $_.Alias).LastName}},
                            RecipientType,
                            PrimarySmtpAddress, 
                            @{Name="Aliases";Expression={($_.EmailAddresses | Where-Object {($_ -clike "smtp:*") -and ($_ -notlike "*onmicrosoft*")} | ForEach-Object {$_ -replace "smtp:",""}) -join "," }}

$userHash = @(
    @{ Label = "EmailAddress"; Expression = {$_.PrimarySMTPAddress} },
    @{ Label = "FirstName"; Expression = {$_.FirstName} },
    @{ Label = "LastName"; Expression = {$_.LastName} },
    @{ Label = "Password"; Expression = {(New-SecurePassword)} },
    @{ Label = "Services"; Expression = {$zix_Services} },
    @{ Label = "SendWelcomeEmail"; Expression = {$zix_welcomemail} },
    @{ Label = "Culture"; Expression = {$zix_culture} },
    @{ Label = "GeoLocation"; Expression = {$zix_geolocation} },
    @{ Label = "AlternateContactEmailAddress"; Expression = {""} },
    @{ Label = "AliasEmailAddresses"; Expression = {$_.Aliases } }
) 

$userlist | Select-Object $userHash | Export-Csv $exportpath -NoTypeInformation

Write-Output "You will find the results in $exportpath"
Write-Output `n
Write-Output "Open the file, fill any empty FirstName and LastName fields,"
Write-Output " and save as XLSX file to be emailed to AppRiver Support."
Invoke-Item $exportpath

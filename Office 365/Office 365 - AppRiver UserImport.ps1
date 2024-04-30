Set-ExecutionPolicy RemoteSigned

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
if (!(Get-Module -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Force
}
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

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
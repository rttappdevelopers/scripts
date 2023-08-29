Try {Set-ExecutionPolicy RemoteSigned} catch {Write-Output "Run PowerShell as administrator"; exit}
$ErrorActionPreference = "Stop"

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

# Connect to MS 365
Write-Output "Connecting to Office 365 `n"
if (!(Get-InstalledModule -Name "MSOnline")) {
Install-Module -Name MSOnline
Import-Module MSOnline
}
else {
Import-Module MSOnline
}
Connect-MsolService

# Begin operations
Function New-SecurePassword {
$zix_password = "!?@#$%^&*123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray()
($zix_password | Get-Random -Count 20) -Join ''
}

Write-Output "Pulling data from Office 365 tenant. `n"
$userlist = Get-MsolUser -All | Where-Object {$_.isLicensed -eq $true} | Select-Object UserPrincipalName, FirstName, LastName, @{Name="Aliases";Expression={($_.ProxyAddresses | Where-Object {($_ -clike "smtp:*") -and ($_ -notlike "*onmicrosoft*") -and ($_ -notlike "*.lan*")} | ForEach-Object {$_ -replace "smtp:",""}) -join "," }}

$userHash = @(
    @{ Label = "EmailAddress"; Expression = {$_.UserPrincipalName} },
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
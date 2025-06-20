# Get mailbox statistics for each user in Office 365 and output to CSV
# check for and create output directory C:\temp if it does not exist
if (-not (Test-Path -Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType "directory"
}

$file = "C:\temp\Office 365 - Mailbox Usage.csv"

# Get user mail rules and forwarding
Set-ExecutionPolicy RemoteSigned

# Is the Exchange Online Management PowerShell module installed? If not, install it
Write-Output "Connecting to Office 365"
if (!(Get-InstalledModule -Name "ExchangeOnlineManagement")) {
    Install-Module -Name ExchangeOnlineManagement
    Import-Module ExchangeOnlineManagement
}
else {
    Import-Module ExchangeOnlineManagement
}

# sign into Office 365
Connect-ExchangeOnline

# Get mailbox usage statistics
$mailboxUsage = Get-EXOMailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"} | ForEach-Object {
    $mbx = $_
    $stats = Get-EXOMailboxStatistics -Identity $mbx.UserPrincipalName -PropertySet All
    [PSCustomObject]@{
        DisplayName           = $mbx.DisplayName
        'MailboxSize in MB'   = "{0:N0}" -f ($stats.TotalItemSize.Value.ToMB())
        ItemCount             = $stats.ItemCount
        LastLogonTime         = $stats.LastLogonTime
        MailboxType           = $mbx.MailboxType
        PrimarySMTPAddress    = $mbx.PrimarySmtpAddress
    }
}

# Output mailbox usage statistics to CSV
$mailboxUsage | Export-Csv -Path $file -NoTypeInformation

# echo that the file has been created, including full path and file size
$fileSize = (Get-Item $file).Length
Write-Output "File created: $file"
Write-Output "File size: $fileSize bytes"

# output mailbox usage statistics to screen
$mailboxUsage | Format-Table -AutoSize

# open file
Invoke-Item $file

# sign out of Office 365
Disconnect-ExchangeOnline -Confirm:$false

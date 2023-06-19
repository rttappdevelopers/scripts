# Get user mail rules and forwarding
Set-ExecutionPolicy RemoteSigned
# $includehidden = "-includehidden"

# Is the Exchange Online Management PowerShell module installed? If not, install it
Write-Output "Connecting to Office 365"
if (!(Get-InstalledModule -Name "ExchangeOnlineManagement")) {
        Install-Module -Name ExchangeOnlineManagement -RequiredVersion 1.0.1
        Import-Module ExchangeOnlineManagement
    }
    else {
        Import-Module ExchangeOnlineManagement
    }

# Connect to Office 365 platform
#$globaladmin = Read-Host "Enter Global Administrator username (full e-mail address)"
Connect-ExchangeOnline # -UserPrincipalName $globaladmin

$userid = Read-Host "Enter mailbox address to fetch rules from, or * for all"

if ($userid -eq "*") {
        $Mailboxes = Get-Mailbox -ResultSize unlimited  | Where-Object {$_.RecipientTypeDetails -eq "UserMailbox"}
        foreach ($Mailbox in $Mailboxes){
            Get-Mailbox $userid  | Select-Object UserPrincipalName,ForwardingSmtpAddress,DeliverToMailboxAndForward | Export-CSV "C:\temp\mailforwards.csv" -Append
            Get-InboxRule -Mailbox $Mailbox.UserPrincipalName $includehidden | Select-Object MailboxOwnerID,Name,Enabled, priority, Description | Export-CSV "C:\temp\mailrules.csv" -Append
        }
    } else {
        Get-Mailbox $userid  | Select-Object UserPrincipalName,ForwardingSmtpAddress,DeliverToMailboxAndForward | Export-CSV "C:\temp\mailforwards.csv" -Append
        Get-InboxRule -Mailbox $Mailbox.UserPrincipalName $includehidden | Select-Object MailboxOwnerID,Name,Enabled, priority, Description | Export-CSV "C:\temp\mailrules.csv"
    }

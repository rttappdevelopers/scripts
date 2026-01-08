# Get user mail rules and forwarding
Set-ExecutionPolicy RemoteSigned

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
Connect-ExchangeOnline

$userid = Read-Host "Enter mailbox address to fetch rules from, or * for all"

if ($userid -eq "*") {
        $Mailboxes = Get-Mailbox -ResultSize unlimited  | Where-Object {$_.RecipientTypeDetails -eq "UserMailbox"}
        foreach ($Mailbox in $Mailboxes){
            $forwardInfo = Get-Mailbox $Mailbox.UserPrincipalName | Select-Object UserPrincipalName,ForwardingSmtpAddress,DeliverToMailboxAndForward
            $forwardInfo | Export-CSV "C:\temp\mailforwards.csv" -Append
            
            $rules = Get-InboxRule -Mailbox $Mailbox.UserPrincipalName -IncludeHidden | Select-Object MailboxOwnerID,Name,Enabled, priority, Description
            $rules | Export-CSV "C:\temp\mailrules.csv" -Append
            
            Write-Output "`nForwarding for $($Mailbox.UserPrincipalName):"
            $forwardInfo | Format-Table -AutoSize
            Write-Output "Rules for $($Mailbox.UserPrincipalName):"
            $rules | Format-Table -AutoSize
        }
    } else {
        $forwardInfo = Get-Mailbox $userid | Select-Object UserPrincipalName,ForwardingSmtpAddress,DeliverToMailboxAndForward
        $forwardInfo | Export-CSV "C:\temp\mailforwards.csv" -Append
        $forwardInfo | Format-Table -AutoSize
        
        $rules = Get-InboxRule -Mailbox $userid -IncludeHidden | Select-Object MailboxOwnerID,Name,Enabled, priority, Description
        $rules | Export-CSV "C:\temp\mailrules.csv"
        $rules | Format-Table -AutoSize
    }

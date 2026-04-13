#Requires -Version 7
<#
.SYNOPSIS
    Retrieves inbox rules and forwarding settings for Exchange Online mailboxes.

.DESCRIPTION
    Connects to Exchange Online and retrieves inbox rules, forwarding SMTP
    addresses, and deliver-to-mailbox settings for a specified user or all
    user mailboxes. Results are exported to C:\temp\mailrules.csv and
    C:\temp\mailforwards.csv.

.NOTES
    Name:    Get Mailbox Rules and Forwards
    Author:  RTT Support
    Context: Technician workstation (interactive)
#>

param()

# Is the Exchange Online Management PowerShell module installed? If not, install it
Write-Output "Connecting to Office 365"
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# Connect to Office 365 platform
# -DisableWAM bypasses Web Account Manager to fix sign-in errors in elevated/non-standard terminals (e.g. running from C:\WINDOWS\system32).
Connect-ExchangeOnline -DisableWAM

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

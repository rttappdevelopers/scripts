<#
.SYNOPSIS
    Gets all folder shares on a server and their associated permissions.

.DESCRIPTION
    This script retrieves all SMB shares on the local or remote server and displays
    the users and security groups that have access to each share along with their
    permission levels. By default, excludes system shares and runs on localhost.

.PARAMETER ComputerName
    The name of the computer to query. Defaults to localhost.

.PARAMETER IncludeSystemShares
    Switch to include default system shares (C$, ADMIN$, IPC$, etc.). By default, system shares are excluded.

.EXAMPLE
    .\Get-FolderSharesAndPermissions.ps1
    Gets shares and permissions for localhost, excluding system shares.

.EXAMPLE
    .\Get-FolderSharesAndPermissions.ps1 -ComputerName "SERVER01" -IncludeSystemShares
    Gets shares and permissions for SERVER01, including system shares.
#>

[CmdletBinding()]
param(
    [string]$ComputerName = "localhost",
    [switch]$IncludeSystemShares
)

# Define built-in and system accounts to exclude (defined once for the entire script)
$script:SystemAccounts = @(
    'NT AUTHORITY\SYSTEM',
    'BUILTIN\Administrators',
    #'BUILTIN\Users',
    #'BUILTIN\Guests',
    #'BUILTIN\Power Users',
    #'BUILTIN\Backup Operators',
    #'NT AUTHORITY\Authenticated Users',
    'NT AUTHORITY\NETWORK',
    'NT AUTHORITY\INTERACTIVE',
    'NT AUTHORITY\SERVICE',
    'NT AUTHORITY\BATCH'#,
    #'NT AUTHORITY\ANONYMOUS LOGON',
    #'CREATOR OWNER',
    #'CREATOR GROUP'
)

function Get-SharePermissions {
    param(
        [string]$ShareName,
        [string]$Computer
    )
    
    try {
        # Get share permissions - handle localhost differently
        if ($Computer -eq "localhost" -or $Computer -eq $env:COMPUTERNAME) {
            $sharePermissions = Get-SmbShareAccess -Name $ShareName -ErrorAction Stop
        } else {
            $sharePermissions = Get-SmbShareAccess -Name $ShareName -CimSession $Computer -ErrorAction Stop
        }
        
        $permissions = @()
        foreach ($permission in $sharePermissions) {
            # Skip system accounts using the script-level variable
            if ($permission.AccountName -notin $script:SystemAccounts) {
                $permissions += [PSCustomObject]@{
                    AccountName = $permission.AccountName
                    AccessControlType = $permission.AccessControlType
                    AccessRight = $permission.AccessRight
                }
            }
        }
        return $permissions
    }
    catch {
        Write-Warning "Could not retrieve permissions for share '$ShareName': $($_.Exception.Message)"
        return @()
    }
}

function Get-FolderPermissions {
    param(
        [string]$FolderPath,
        [string]$Computer
    )
    
    try {
        if ($Computer -eq "localhost" -or $Computer -eq $env:COMPUTERNAME) {
            $acl = Get-Acl -Path $FolderPath -ErrorAction Stop
        } else {
            # For remote computers, construct UNC path
            $uncPath = "\\$Computer\$($FolderPath.Replace(':', '$'))"
            $acl = Get-Acl -Path $uncPath -ErrorAction Stop
        }
        
        $permissions = @()
        foreach ($access in $acl.Access) {
            # Skip system accounts using the script-level variable
            if ($access.IdentityReference -notin $script:SystemAccounts) {
                $permissions += [PSCustomObject]@{
                    IdentityReference = $access.IdentityReference
                    FileSystemRights = $access.FileSystemRights
                    AccessControlType = $access.AccessControlType
                    InheritanceFlags = $access.InheritanceFlags
                    PropagationFlags = $access.PropagationFlags
                }
            }
        }
        return $permissions
    }
    catch {
        Write-Warning "Could not retrieve folder permissions for '$FolderPath': $($_.Exception.Message)"
        return @()
    }
}

try {
    Write-Host "Retrieving shares from computer: $ComputerName" -ForegroundColor Green
    
    # Get all SMB shares - handle localhost differently
    if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
        $shares = Get-SmbShare -ErrorAction Stop
    } else {
        $shares = Get-SmbShare -CimSession $ComputerName -ErrorAction Stop
    }
    
    # Exclude system shares by default (unless IncludeSystemShares is specified)
    if (-not $IncludeSystemShares) {
        $systemShares = @('ADMIN$', 'C$', 'D$', 'E$', 'F$', 'G$', 'H$', 'IPC$', 'print$')
        $shares = $shares | Where-Object { $_.Name -notin $systemShares }
        Write-Host "Excluding system shares (use -IncludeSystemShares to include them)" -ForegroundColor Gray
    }
    
    $results = @()
    
    foreach ($share in $shares) {
        Write-Host "Processing share: $($share.Name)" -ForegroundColor Yellow
        
        # Get share-level permissions
        $sharePermissions = Get-SharePermissions -ShareName $share.Name -Computer $ComputerName
        
        # Get folder-level permissions (NTFS)
        $folderPermissions = @()
        if ($share.Path -and (Test-Path $share.Path -ErrorAction SilentlyContinue)) {
            $folderPermissions = Get-FolderPermissions -FolderPath $share.Path -Computer $ComputerName
        }
        
        $shareInfo = [PSCustomObject]@{
            ComputerName = $ComputerName
            ShareName = $share.Name
            SharePath = $share.Path
            ShareDescription = $share.Description
            ShareType = $share.ShareType
            ShareState = $share.ShareState
            SharePermissions = $sharePermissions
            FolderPermissions = $folderPermissions
        }
        
        $results += $shareInfo
    }
    
    # Display results
    Write-Host "`n=== SHARE AND PERMISSIONS REPORT ===" -ForegroundColor Cyan
    Write-Host "Computer: $ComputerName" -ForegroundColor Cyan
    Write-Host "Generated: $(Get-Date)" -ForegroundColor Cyan
    Write-Host "Total Shares Found: $($results.Count)" -ForegroundColor Cyan
    
    foreach ($result in $results) {
        Write-Host "`n" + "="*80 -ForegroundColor White
        Write-Host "SHARE: $($result.ShareName)" -ForegroundColor Green
        Write-Host "Path: $($result.SharePath)" -ForegroundColor Gray
        Write-Host "Description: $($result.ShareDescription)" -ForegroundColor Gray
        Write-Host "Type: $($result.ShareType)" -ForegroundColor Gray
        Write-Host "State: $($result.ShareState)" -ForegroundColor Gray
        
        Write-Host "`nSHARE-LEVEL PERMISSIONS:" -ForegroundColor Yellow
        if ($result.SharePermissions.Count -gt 0) {
            $result.SharePermissions | Format-Table -Property AccountName, AccessControlType, AccessRight -AutoSize
        } else {
            Write-Host "  No share permissions found or access denied" -ForegroundColor Red
        }
        
        Write-Host "FOLDER-LEVEL PERMISSIONS (NTFS):" -ForegroundColor Yellow
        if ($result.FolderPermissions.Count -gt 0) {
            $result.FolderPermissions | Format-Table -Property IdentityReference, FileSystemRights, AccessControlType -AutoSize
        } else {
            Write-Host "  No folder permissions found or access denied" -ForegroundColor Red
        }
    }
    
    # Export to CSV option
    $exportChoice = Read-Host "`nWould you like to export results to CSV? (Y/N)"
    if ($exportChoice -eq 'Y' -or $exportChoice -eq 'y') {
        $csvPath = "SharePermissions_$($ComputerName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        $csvData = @()
        foreach ($result in $results) {
            foreach ($sharePerm in $result.SharePermissions) {
                $csvData += [PSCustomObject]@{
                    ComputerName = $result.ComputerName
                    ShareName = $result.ShareName
                    SharePath = $result.SharePath
                    PermissionType = "Share"
                    AccountName = $sharePerm.AccountName
                    AccessControlType = $sharePerm.AccessControlType
                    AccessRight = $sharePerm.AccessRight
                    FileSystemRights = ""
                }
            }
            
            foreach ($folderPerm in $result.FolderPermissions) {
                $csvData += [PSCustomObject]@{
                    ComputerName = $result.ComputerName
                    ShareName = $result.ShareName
                    SharePath = $result.SharePath
                    PermissionType = "Folder"
                    AccountName = $folderPerm.IdentityReference
                    AccessControlType = $folderPerm.AccessControlType
                    AccessRight = ""
                    FileSystemRights = $folderPerm.FileSystemRights
                }
            }
        }
        
        $csvData | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Results exported to: $csvPath" -ForegroundColor Green
        
        # Offer to open the CSV file
        $openChoice = Read-Host "Would you like to open the CSV file? (Y/N)"
        if ($openChoice -eq 'Y' -or $openChoice -eq 'y') {
            try {
                Start-Process $csvPath
                Write-Host "Opening CSV file with default application..." -ForegroundColor Green
            }
            catch {
                Write-Warning "Could not open CSV file: $($_.Exception.Message)"
                Write-Host "File location: $csvPath" -ForegroundColor Yellow
            }
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Host "Make sure you have the required permissions and the target computer is accessible." -ForegroundColor Red
}
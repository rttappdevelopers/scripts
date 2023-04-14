# Common exclusions
$exclusions = @('Name1', 'Name 2')

# Add additional exclusions to array above, if supplied in RMM job
$exclude = $env:exclude
$demote = $env:demote

if ([string]::IsNullOrEmpty($exclude)) { 
    $exclusionsTotal = $exclusions
} else {
    $excludeArray = $exclude.split(',')
    $exclusionsTotal = $exclusions + $excludeArray
}
Write-Output "Excluding from audit (regardless of presence on system): $exclusionsTotal"


# Get user list from system
Write-Output "`nAuditing users in Administrators group.`n"
$usersareadmins = (Get-LocalGroupMember administrators | Select-Object Name)

# Compare user list in system with exclusions listed in array
$filteredUsers = $usersareadmins | Where-Object {
    $currentUser = $_.Name.Split('\')[-1]
    -not ($exclusionsTotal -contains $currentUser)
}

$filteredUsersCount = ($filteredUsers | Measure-Object).Count
Write-Output "Number of identified users: $filteredUsersCount"
Write-Output "Identified users: $filteredUsers"

# Are we demoting the listed users?
If ($demote -eq "yes")
{
    $filteredUsers | ForEach-Object {
        $userToRemove = $_.Name
    
        # Check if the user is a member of the Users group
        $isUserInUsersGroup = (Get-LocalGroupMember -Group "Users" -Member $userToRemove -ErrorAction SilentlyContinue) -ne $null
    
        # Add the user to the Users group if they are not a member
        if (-not $isUserInUsersGroup) {
            Write-Output "Adding user to the Users group: $userToRemove"
            Add-LocalGroupMember -Group "Users" -Member $userToRemove
        }
    
        # Remove the user from the Administrators group
        Write-Output "Removing user from the Administrators group: $userToRemove"
        Remove-LocalGroupMember -Group "Administrators" -Member $userToRemove
        if ($?) {$filteredUsersCount--}
    }
    Write-Output "`nUsers demoted successfully.`n"

}

# Post the count of non-IT admin users to the RMM User Defined Field for the computer
Write-Output "Logging resulting users: $filteredUsersCount"
Set-ItemProperty "HKLM:\Software\CentraStage" -Name "Custom5" -Value "$filteredUsersCount"
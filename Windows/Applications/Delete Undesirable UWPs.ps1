# Remove undesirable Windows UWP applications and their cached prior versions
# Use when C:\Program Files\WindowsApps occupies too much space
# Run as SYSTEM

# Edit list as necessary
# Note that Microsoft.Office here is not the same as the Office 365 application suite
$undesirables = @(
    'AdobePhotoshopExpress',
    'BingNews',
    'CandyCrush',
    'CCleaner',
    'DisneyMagicKingdoms',
    'Duolingo',
    'HiddenCity',
    'LenovoCompanion',
    'McAffee',
    'Microsoft.Office',
    'Microsoft.Office.Desktop',
    'Microsoft.Office.OneNote',
    'Microsoft.Todos',
    'Microsoft.Whiteboard',
    'MinecraftUWP',
    'OneNote',
    'Spotify'
    )

# Additional patterns for language-specific packages
$languagePatterns = @(
    '*OneNote*pt-br*',
    '*OneNote*fr-fr*',
    '*OneNote*es-es*',
    '*OneNote*en-us*',
    '*365*pt-br*',
    '*365*fr-fr*',
    '*365*es-es*',
    '*365*en-us*',
    '*Office*pt-br*',
    '*Office*fr-fr*',
    '*Office*es-es*',
    '*Office*en-us*'
)

# Get current disk space
Write-Output "Starting storage space"
Get-Volume
Write-Output "`n"

# Uninstall applications and delete cached folders
foreach ($undesirable in $undesirables) {
    Write-Output "Processing $undesirable"
    
    # First, find and uninstall any installed packages
    $packages = Get-AppxPackage -AllUsers "*$undesirable*"
    if ($packages) {
        Write-Output "Found installed packages for $undesirable"
        $packages | Select-Object Name, PackageFullName | Format-Table
        
        foreach ($package in $packages) {
            try {
                Write-Output "Uninstalling $($package.Name)"
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                Write-Output "Successfully uninstalled $($package.Name)"
            }
            catch {
                Write-Output "Failed to uninstall $($package.Name): $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Output "No installed packages found for $undesirable"
    }
    
    # Then, remove any remaining cached folders
    $folders = Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter "*$undesirable*" -ErrorAction SilentlyContinue
    if ($folders) {
        Write-Output "Found cached folders for $undesirable"
        foreach ($folder in $folders) {
            try {
                Write-Output "Removing folder: $($folder.Name)"
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                Write-Output "Successfully removed folder: $($folder.Name)"
            }
            catch {
                Write-Output "Failed to remove folder $($folder.Name): $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Output "No cached folders found for $undesirable"
    }
    
    Write-Output "---"
}

# Process language-specific patterns
Write-Output "Processing language-specific Office/OneNote packages..."
foreach ($pattern in $languagePatterns) {
    Write-Output "Processing pattern: $pattern"
    
    # Find and uninstall packages matching language patterns
    $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern }
    if ($packages) {
        Write-Output "Found language-specific packages matching $pattern"
        $packages | Select-Object Name, PackageFullName | Format-Table
        
        foreach ($package in $packages) {
            try {
                Write-Output "Uninstalling $($package.Name)"
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                Write-Output "Successfully uninstalled $($package.Name)"
            }
            catch {
                Write-Output "Failed to uninstall $($package.Name): $($_.Exception.Message)"
            }
        }
    }
    
    # Remove cached folders matching language patterns
    $folders = Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter $pattern -ErrorAction SilentlyContinue
    if ($folders) {
        Write-Output "Found cached folders matching $pattern"
        foreach ($folder in $folders) {
            try {
                Write-Output "Removing folder: $($folder.Name)"
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                Write-Output "Successfully removed folder: $($folder.Name)"
            }
            catch {
                Write-Output "Failed to remove folder $($folder.Name): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Output "---"
}

# Get ending disk space
Write-Output "`nStorage space after clean-up"
Get-Volume
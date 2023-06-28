# Remove undesirable Windows UWP applications and their cached prior versions
# Use when C:\Program Files\WindowsApps occupies too much space
# Run as SYSTEM

# Edit list as necessary
# Note that Microsoft.Office here is not the same as the Office 365 application suite
$undesirables = @(
    'AdobePhotoshopExpress',
    'BingNews',
    'CandyCrush',
    'DisneyMagicKingdoms',
    'Duolingo',
    'HiddenCity',
    'LenovoCompanion',
    'Microsoft.Office',
    'Microsoft.Todos',
    'Microsoft.Whiteboard',
    'MinecraftUWP'
    )

# Get current disk space
Write-Out "Starting storage space"
Get-Volume
Write-Out "`n"

# Uninstall application even if it isn't listed as installed in Control Panel
# and delete the cached folder
foreach ($undesirable in $undesirables) {
    Write-Out "Checking for $undesirable"
    Get-AppxPackage -allusers  *$undesirable* | Select-Object Name, PackageFullName
    Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter "*$undesirable*" | Remove-Item -Recurse -Force
    }

# Get ending disk space
Write-Out "`nStorage space after clean-up"
Get-Volume
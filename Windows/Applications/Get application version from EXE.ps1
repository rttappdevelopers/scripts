# This script checks each user profile on the system for the Product Version of an executable application file.

# Get all user profile directories, excluding system and public profiles.
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory | Where-Object {
    $_.Name -notin @('Public', 'Default', 'All Users')
}

# Create an empty array to store the results.
$results = @()

# Loop through each user profile found.
foreach ($user in $userProfiles) {
    # Define the expected path for the 8x8 Work executable.
    $exePath = Join-Path -Path $user.FullName -ChildPath "AppData\Local\8x8-Work\8x8 Work.exe"

    # Check if the application's executable file exists at the defined path.
    if (Test-Path -Path $exePath) {
        try {
            # If the file exists, retrieve its Product Version.
            $productVersion = (Get-Item -Path $exePath).VersionInfo.ProductVersion
            
            # Add the user and version information to the results array.
            $results += [PSCustomObject]@{
                UserName         = $user.Name
                '8x8_Work_Version' = $productVersion
                Status           = 'Installed'
            }
        } catch {
            # Handle cases where the file exists but cannot be read (e.g., permissions error).
             $results += [PSCustomObject]@{
                UserName         = $user.Name
                '8x8_Work_Version' = 'Error Reading File'
                Status           = 'Access Denied or Error'
            }
        }
    }
}

# Display the collected results in a clean, formatted table.
if ($results) {
    $results | Format-Table -AutoSize
} else {
    Write-Host "No users found with 8x8 Work installed."
}
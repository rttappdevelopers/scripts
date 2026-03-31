# This script checks each user profile on the system for the Product Name and Product Version of an executable application file.

# Get all user profile directories, excluding system and public profiles.
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory | Where-Object {
    $_.Name -notin @('Public', 'Default', 'All Users')
}

# Create an empty array to store the results.
$results = @()

# Get the executable path from environment variable, with fallback to default
$exeRelativePath = "\AppData\Local\8x8-Work\8x8 Work.exe"  # Default fallback
try {
    $ninjaPath = $env:exepath
    if ($ninjaPath) {
        $exeRelativePath = $ninjaPath
        Write-Host "Using executable path from environment variable: $exeRelativePath"
    } else {
        Write-Host "Environment variable 'exepath' is empty, using default path: $exeRelativePath"
    }
} catch {
    Write-Host "Error getting environment variable 'exepath': $($_.Exception.Message) - using default path"
}

# Use generic column names instead of filename-based ones
$versionColumnName = 'ProductVersion'
$productNameColumnName = 'ProductName'

# Loop through each user profile found.
foreach ($user in $userProfiles) {
    # Define the expected path for the executable using the retrieved path.
    $exepath = Join-Path -Path $user.FullName -ChildPath $exeRelativePath

    # Check if the application's executable file exists at the defined path.
    if (Test-Path -Path $exepath) {
        try {
            # If the file exists, retrieve its Product Version and Product Name.
            $versionInfo = (Get-Item -Path $exepath).VersionInfo
            $productVersion = $versionInfo.ProductVersion
            $productName = $versionInfo.ProductName

            # Add the user, product name, and version information to the results array.
            $results += [PSCustomObject]@{
                UserName                   = $user.Name
                $productNameColumnName     = $productName
                $versionColumnName         = $productVersion
                Status                     = 'Installed'
            }
        } catch {
            # Handle cases where the file exists but cannot be read (e.g., permissions error).
             $results += [PSCustomObject]@{
                UserName                   = $user.Name
                $productNameColumnName     = 'Error Reading File'
                $versionColumnName         = 'Error Reading File'
                Status                     = 'Access Denied or Error'
            }
        }
    }
}

# Display the collected results in a comma-delimited single line format
if ($results) {
    # Group results by product name
    $groupedResults = $results | Group-Object -Property $productNameColumnName
    
    $outputLines = @()
    foreach ($group in $groupedResults) {
        $productName = $group.Name
        $userVersions = $group.Group | ForEach-Object { "$($_.UserName) $($_.$versionColumnName)" }
        $outputLines += "$productName`: $($userVersions -join ', ')"
    }
    # Join the output lines into a single string
    $endresult = $outputLines -join ', '
    Write-Host ($endresult)
} else {
    # Report that no users have the executable installed
    $endresult = "No users found with the executable installed."
    Write-Host $endresult
}

# Set Ninja RMM property if command exists
try {
    if (Get-Command "Ninja-Property-Set" -ErrorAction SilentlyContinue) {
        Ninja-Property-Set softwareAudit $endresult
        Write-Host "Successfully set Ninja RMM property 'softwareAudit'"
    } else {
        Write-Host "Ninja RMM command not available - skipping property set"
    }
} catch {
    Write-Host "Error setting Ninja RMM property: $($_.Exception.Message)"
}
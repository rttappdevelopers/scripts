# Created by Brad Brown with the help of GitHub CoPilot 20250619
# Source of installation package: https://help.dialpad.com/docs/download-the-apps-via-msi-or-pkg
$dialpadExe = "C:\Program Files (x86)\Dialpad Installer\dialpad.exe"

if (-not (Test-Path -Path $dialpadExe -ErrorAction SilentlyContinue)) {
    Write-Output "Dialpad is not installed. Installing Dialpad..."
    $msiUrl = "https://storage.googleapis.com/dialpad_native/x64/DialpadSetup_x64.msi"
    $msiPath = "$env:TEMP\DialpadSetup_x64.msi"

    # Download the MSI file
    try {
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to download Dialpad installer."
        exit 1
    }

    # Ensure the MSI file exists before attempting to install
    if (Test-Path -Path $msiPath) {
        # Install the MSI file and wait for completion
        $process = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Error "Dialpad installation failed with exit code $($process.ExitCode)."
            exit 1
        }
        Write-Output "Dialpad installation completed."
    } else {
        Write-Error "MSI file not found after download."
        exit 1
    }

    # Check if the installation was successful
    if (-not (Test-Path -Path $dialpadExe)) {
        Write-Error "Dialpad installation did not complete successfully. Dialpad executable not found."
        exit 1
    }
    Write-Output "Dialpad has been successfully installed."
    
} else {
    Write-Output "Dialpad is already installed."
}

# Clean up the downloaded MSI file
Remove-Item -Path $msiPath -Force 2>$null

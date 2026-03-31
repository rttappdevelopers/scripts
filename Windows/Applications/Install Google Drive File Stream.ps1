# Block GoogleDriveFS.exe from running post-install
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\GoogleDriveFS.exe" -Name "Debugger" -Value "C:\Windows\System32\systray.exe"

# Download Google Drive File Stream
Invoke-WebRequest -Uri "https://dl.google.com/drive-file-stream/GoogleDriveFSSetup.exe" -OutFile "GoogleDriveFSSetup.exe"

# Install Google Drive File Stream
Start-Process -FilePath "GoogleDriveFSSetup.exe" -ArgumentList "--silent", "--desktop_shortcut" -Wait

# Wait for 20 seconds
Start-Sleep -Seconds 20

# Unblock GoogleDriveFS.exe from running
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\GoogleDriveFS.exe" -Force

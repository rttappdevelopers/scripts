$drop = "\Appdata\Roaming\Dropbox"

$dropboxProcess = Get-Process -Name "dropbox" -ErrorAction SilentlyContinue
if ($dropboxProcess) {
    Stop-Process -Name "dropbox" -Force
}

$uninstallerPath = "C:\Program Files (x86)\Dropbox\Client\DropboxUninstaller.exe"
if (Test-Path $uninstallerPath) {
    Start-Process -FilePath $uninstallerPath -ArgumentList "/S" -Wait -NoNewWindow
}

$users = Get-ChildItem -Path "C:\Users" -Directory
foreach ($user in $users) {
    $userDropboxPath = Join-Path -Path $user.FullName -ChildPath $drop
    if (Test-Path $userDropboxPath) {
        Remove-Item -Path $userDropboxPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

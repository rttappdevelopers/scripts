# Outlook Clear Local OST Files (WIN)
# This script will kill the outlook.exe, clear local ost files to mitigate outlook launch issues. This will essentially open outlook and the program will require to re-download emails etc.

# Kill Outlook and clear NST and OST Files
$p = Get-Process -Name "Outlook"
Stop-Process -InputObject $p
Get-Process | Where-Object {$_.HasExited}

# Delete OST and NST Files for outlook
$users = Get-ChildItem c:\users
foreach ($user in $users){
    $folder = "C:\users\" + $user +"\AppData\Local\Microsoft\Outlook" 
    $folderpath = test-path -Path $folder
    if($folderpath)
    {
        Get-ChildItem $folder | Where-Object {$_.extension -in ".ost",".nst"} | remove-item
        Write-Output "Deleted OST file for $user"
    }
    else{
        Write-Output "OST file doesn't exist or meet criteria for $user"
    }
}
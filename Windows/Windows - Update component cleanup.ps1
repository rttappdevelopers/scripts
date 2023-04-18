# Cleans up cached components of Windows Update installation packages, which allow updates to be rolled back. These are stored in the WinSXS folder, which over a length of time can grow unwieldy in size.
# The /Cleanup-Image parameter of Dism.exe provides options to reduce the size of the WinSxS folder. Using the /ResetBase parameter together with the /StartComponentCleanup parameter of DISM.exe on a running version of Windows 10 or later removes all superseded versions of every component in the component store. However, all existing service packs and updates cannot be uninstalled after a rebase, select wisely!

# Establish variables based on what environment variables are supplied by the RMM
$action = $env:action

# Run regular cleanup
Dism.exe /online /Cleanup-Image /StartComponentCleanup

# If we are rebasing, run the command to do so
if ($action -eq "rebase") {
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
}

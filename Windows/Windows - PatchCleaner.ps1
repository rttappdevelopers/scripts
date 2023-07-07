# Script must be packaged with PatchCleaner Portable
# Download from https://sourceforge.net/projects/patchcleaner/
# Update folder and file version numbers below if newer version

if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -ge 394802) {
    Write-Output Uncompressing PatchCleaner
    .\7za.exe x PatchCleanerPortable_1_4_2_0.zip -y
    
    Write-Output Running PatchCleaner
    Set-Location .\PatchCleanerPortable_1_4_2_0\PatchCleaner\
    .\PatchCleaner.exe /d

    exit 0
    }
    else
    {
    Write-Output Install .NET 4.5.2
    exit 1
    }
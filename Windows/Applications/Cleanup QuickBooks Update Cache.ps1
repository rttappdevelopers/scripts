# QuickBooks Update Cache Cleanup [WIN]
# Deletes cached copies of QuickBooks update installation packages that aren't cleaned up by the application once it is updated.

Get-ChildItem "C:\ProgramData\Intuit\QuickBooks 20*\Components\DownloadQB*\SPatch\*.dat" -Force | Remove-Item -Recurse -Force
Get-ChildItem "C:\ProgramData\Intuit\QuickBooks 20*\Components\QBUpdateCache" -Force | Remove-Item -Recurse -Force

# Dell SupportAssist Snapshot Clean-up
# Removes Dell SupportAssist Snapshot folders after software is uninstalled. Use if these folders don't automatically get removed.

Get-ChildItem -Path "C:\ProgramData\Dell\SARemediation\SystemRepair\Snapshots\Backup" | Remove-Item -Recurse -Force
Get-ChildItem -Path "C:\Users\All Users\Dell\SARemediation\SystemRepair\Snapshots\Backup" | Remove-Item -Recurse -Force
$printers = Get-Printer | Where-Object { $_.Name -notmatch 'fax|pdf|OneNote' } | Select-Object Name, PortName | Format-Table -HideTableHeaders | Out-String
$printers 
Ninja-Property-Set printers $printers
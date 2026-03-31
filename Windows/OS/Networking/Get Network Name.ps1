$output = get-netconnectionProfile | Select-Object Name, InterfaceAlias | Format-Table -HideTableHeaders | Out-String
$output 
Ninja-Property-Set networkName $output
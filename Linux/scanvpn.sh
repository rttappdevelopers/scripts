#!/bin/env bash
# Scans a list of IP addresses supplied by a file named input.file
# for common SSL VPN ports to see if they are listening.

# Check for prerequisite 'nmap'
command -v nmap >/dev/null 2>&1 || echo "Error: The application 'nmap' is not installed." >&2

# Check for input file
[ ! -f input.file ] && echo "Error: The file 'input.file' does not exist. Create the file with a list of IPs to scan, separated by carriage return." >&2 && exit 1

# Execute
while read -r line;
do
    address=$(echo $line | tr -d '\r\n')
    echo -n "$address: "
    result=$(nmap -sV -p 443,4433,8443,10443,11443 $address | grep open) || result="No results"
    echo $result
done < input.file
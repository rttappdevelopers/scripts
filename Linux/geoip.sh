#!/usr/bin/bash
# Check for and install prerequisite 'geoiplookup' with apt
command -v geoiplookup >/dev/null 2>&1 || apt install -y geoip-bin

# Check for supplied filename or stdin
if [ -z "$1" ]; then
    echo "Error: No filename supplied. Usage: $0 <filename>"
    exit 1
fi

# Check each line in the input file for an IP address and run geoiplookup for each, adding the results separated by a comma next to each ip address
while read -r line;
do
    address=$(echo $line | tr -d '\r\n')
    echo -n "$address: "
    result=$(geoiplookup $address | awk -F ": " '{print $2}') || result="No results"
    echo $result
done < $1



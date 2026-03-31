#!/bin/env bash
# Download list of files from a file supplied by user in command line
# Usage: ./download_list.sh <file_with_list_of_files>

# Check if file is supplied
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file_with_list_of_files>"
    exit 1
fi

# Check if file exists
if [ ! -f $1 ]; then
    echo "File $1 not found"
    exit 1
fi

# Read file line by line
while read line; do
    # Download file
    wget $line
done < $1

# Exit
exit 0
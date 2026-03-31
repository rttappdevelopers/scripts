#!/bin/env bash
# Bash script to ping a list of IP addresses from an input file and output the results to screen
# Usage: ./pingips.sh <inputfile>

# Check if input file is provided
if [ $# -eq 0 ]
  then
    echo "No input file provided"
    echo "Usage: ./pingips.sh <inputfile>"
    exit 1
fi

# Check if input file exists
if [ ! -f $1 ]
  then
    echo "Input file does not exist"
    exit 1
fi

# Read input file line by line

while read line
do
  # Check if line is empty
  if [ -z "$line" ]
    then
      continue
  fi

  # Check if line is a comment
  if [[ $line == \#* ]]
    then
      continue
  fi

  # Check if line is a valid IP address
  if [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
    then
      # Ping IP address
      ping -c 1 $line > /dev/null 2>&1

      # Check if ping was successful
      if [ $? -eq 0 ]
        then
          echo "$line is up"
        else
          echo "$line is down"
      fi
    else
      echo "$line is not a valid IP address"
  fi
done < $1

exit 0
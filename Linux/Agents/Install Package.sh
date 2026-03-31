#!/bin/env bash
# Install package [LIN]
# Download and install supplied .deb or .rpm package
echo $packagename

# if no $packagename name is supplied, exit
[ -z $packagename ] && echo "Error: No package name supplied." >&2 && exit 1

wget $packagename

# Trim all but filename from $packagename
packagename=$(echo $packagename | awk -F/ '{print $NF}')

# if $packagename ends in .rpm, install with rpm
if [[ $packagename == *.rpm ]]; then
    rpm -i $packagename
fi

# if $packagename ends in .deb, install with dpkg
if [[ $packagename == *.deb ]]; then
    dpkg -i $packagename
fi

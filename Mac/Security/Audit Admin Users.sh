#!/usr/bin/env bash
# List admin users who aren't root or rttadmin
result=$(dscl . -read /groups/admin GroupMembership | sed 's/ /\n/g' | grep -vE "(GroupMembership|root|rttadmin)")
echo $result

# Populate UDF
/Applications/NinjaRMMAgent/programdata/ninjarmm-cli set administratorUsers $result

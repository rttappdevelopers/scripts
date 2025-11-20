#!/bin/env bash

# Declare variables
cybercnstenantid="" # populate from CS website
cybercnstoken=""    # populate from CS website

# Get the ConnectSecure company ID from NinjaRMM custom field
cybercnscompany_id=$(/opt/NinjaRMMAgent/programdata/ninjarmm-cli get connectsecureCompanyId)

# checking whether the user is root or normal user
function check_root {
    if [[ "x$(id -u)" != 'x0' ]]; then
        echo 'Error: this script can only be executed by root'
        exit 1
    fi
}

# checking whether the agent already exists if not will install the agent
function install_lightweight {

   if [ -z "$cybercnscompany_id" ]
   then
         echo "\$cybercnscompany_id is NULL or not set in NinjaRMM custom field"
         exit 1
   fi

   if [ -z "$cybercnstenantid" ]
   then
         echo "\$cybercnstenantid is NULL"
         exit 1
   fi

   if [ -z "$cybercnstoken" ]
   then
         echo "\$cybercnstoken is NULL"
         exit 1
   fi

   pgrep cybercnsagent
   exitcode=$?
   if [ $exitcode -eq 0 ]; then
      echo "lightweight agent already running in the machine"
   else
      echo "Downloading Cybercns Agent"
      download_url=$(curl -s -L https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=linux)
      exitcode=$(curl --write-out %{http_code} -L -g "$download_url" -s -o cybercnsagent_linux)
      if [ $exitcode -ne 200 ]; then
              if [ "$exitcode" == "000" ]; then
                 exitcode=-1
              fi
              
              echo "Was not able to fetch the lightweight cybercnsagent agent for linux"
              exit $exitcode
      fi
      chmod +x cybercnsagent_linux;
      sudo ./cybercnsagent_linux -c $cybercnscompany_id -e $cybercnstenantid -j $cybercnstoken -i;
   fi
}

function install {
    check_root
    install_lightweight
}

install

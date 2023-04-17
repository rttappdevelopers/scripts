# About
These are commands that one may find useful on Windows workstations and servers. The commands are a mix of DOS/CMD and PowerShell. The easiest way to tell them apart is that DOS commands will be in all capital letters, PowerShell will be mixed-case.

Many of these commands require an elevated command prompt or PowerShell terminal; run as Administrator. If you are working from the DOS command prompt, you can run simple Powershell commands that don't include quotations using the exmaple below:
`powershell -c "Get-Volume C"`

Any text after a # in an example is a remark or comment, which explains what the command does.

<!-- TOC -->

- [About](#about)
- [Filesystem Operations](#filesystem-operations)
    - [Directories](#directories)
    - [Common locations and their aliases](#common-locations-and-their-aliases)
    - [Devices and drives](#devices-and-drives)
    - [File Operation](#file-operation)
- [System Functions](#system-functions)
    - [Run a command](#run-a-command)
    - [Operations](#operations)
    - [Services](#services)
    - [Process list](#process-list)
    - [Kill](#kill)
    - [Aliases](#aliases)
- [Network](#network)
    - [LAN IP](#lan-ip)
    - [WAN IP](#wan-ip)
    - [Domain Name Lookup and DNS Records](#domain-name-lookup-and-dns-records)
    - [Who owns an IP or domain](#who-owns-an-ip-or-domain)
    - [Where is an IP from](#where-is-an-ip-from)
    - [Who is on the network, are they reachable?](#who-is-on-the-network-are-they-reachable)
    - [Remote Command Line](#remote-command-line)
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

```bat
CD \                    # Go to root directory of current drive
CD ..                   # Go back one directory
CD ..\..                # Layered to go back two directories
CD C:\Temp\             # Change directory to the Temp folder on the C: drive
CD "C:\Program Files\"  # Changing to a directory with spaces in the name requires quotes
```

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

##	Devices and drives
```bat
C:  # Enter drive letter and colon to change drive
FORMAT D:
FDISK
DISKPART
```

##	File Operation

# System Functions
##	Run a command
##	Operations
##      Services
```powershell
Get-Service {service}                        # Get service status, by name with quotes or alias
Get-Service {service} | Restart-Service      # Restart the service
```

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
	
# Network
##	LAN IP
##	WAN IP
##	Domain Name Lookup and DNS Records
##	Who owns an IP or domain
##	Where is an IP from
##	Who is on the network, are they reachable?
##	Remote Command Line
	
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
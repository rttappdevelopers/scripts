# Mac

Scripts for macOS endpoint management. These run via NinjaOne RMM or directly from a terminal session.

See [HOWTO.md](../HOWTO.md) for guidance on downloading and running scripts.

---

## Scripts

### Applications

| Script | Description |
|---|---|
| [Install BitDefender GravityZone.sh](Applications/Install%20BitDefender%20GravityZone.sh) | Installs the BitDefender GravityZone endpoint agent on macOS |
| [Install ConnectSecure Agent.sh](Applications/Install%20ConnectSecure%20Agent.sh) | Installs the ConnectSecure (CyberCNS) vulnerability scanning agent on macOS |
| [Install Huntress Agent.sh](Applications/Install%20Huntress%20Agent.sh) | Installs the Huntress agent on macOS via NinjaOne |
| [Uninstall Webroot.sh](Applications/Uninstall%20Webroot.sh) | Removes the Webroot SecureAnywhere agent from macOS |

### OS

| Script | Description |
|---|---|
| [Configure Automatic Updates.sh](OS/Configure%20Automatic%20Updates.sh) | Enables or disables automatic macOS software updates |
| [Create Admin User.sh](OS/Create%20Admin%20User.sh) | Creates a local administrator account on macOS |
| [Create Desktop Shortcut.sh](OS/Create%20Desktop%20Shortcut.sh) | Creates a URL shortcut on the user's Desktop |
| [Get Apple IDs.sh](OS/Get%20Apple%20IDs.sh) | Reports Apple IDs associated with accounts on the device |
| [Set User Password.sh](OS/Set%20User%20Password.sh) | Sets the password for a specified local user account |

### Security

| Script | Description |
|---|---|
| [Audit Admin Users.sh](Security/Audit%20Admin%20Users.sh) | Reports all users with administrator privileges on the device |
| [Detect CVE CloudMensis.sh](Security/Detect%20CVE%20CloudMensis.sh) | Checks for indicators of the CloudMensis macOS spyware |
| [Detect MDM Enrollment.sh](Security/Detect%20MDM%20Enrollment.sh) | Reports whether the device is enrolled in an MDM platform |
| [Get FileVault Key.sh](Security/Get%20FileVault%20Key.sh) | Retrieves the FileVault recovery key for the device |
| [Get FileVault Status.sh](Security/Get%20FileVault%20Status.sh) | Reports the current FileVault encryption status |

---

## Mac-specific commands beyond the usual Linux/POSIX commands.

## Invoke the terminal
🍎+ SPACE > "Term"

# Copy command output to clipboard
```sh
command | pbcopy
```

# Caffeinate to Stay awake
System will stay awake as long as terminal is left running this command
```sh
caffeinate
```


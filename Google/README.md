# Google Workspace

Scripts for auditing and managing Google Workspace environments using [GAM7](https://github.com/GAM-team/GAM), a command-line tool for Google Workspace administrators.

---

## Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Setup](#manual-setup)
  - [Installing GAM7](#installing-gam7)
  - [1. Create directories](#1-create-directories)
  - [2. Set environment variables](#2-set-environment-variables)
  - [3. Initialize GAM](#3-initialize-gam)
  - [4. Create your GCP project](#4-create-your-gcp-project)
  - [5. Authorize client (OAuth) scopes](#5-authorize-client-oauth-scopes)
  - [6. Authorize the service account (domain-wide delegation)](#6-authorize-the-service-account-domain-wide-delegation)
  - [7. Save basic config values](#7-save-basic-config-values)
- [Verifying the Connection](#verifying-the-connection)
- [Running Scripts](#running-scripts)
- [Useful GAM Commands Reference](#useful-gam-commands-reference)
- [Script Index](#script-index)
- [Resources](#resources)

---

## Prerequisites

- **Google Workspace** — Paid, Education, or Non-profit edition (Legacy Free has limited API support)
- **Super Admin access** — Required for initial setup (project creation and domain-wide delegation)
- **Windows workstation** — GAM runs locally from the technician's machine

---

## Quick Start

Run [`Initialize GAM.ps1`](Initialize%20GAM.ps1) once per customer workspace:

```powershell
.\"Initialize GAM.ps1" -AdminEmail admin@customer.com
```

The script handles the full setup end-to-end:

- Installs GAM7 via winget (if not already installed)
- Creates config directories and sets environment variables
- Initializes the GAM config file
- Guides you through GCP project creation (browser-based)
- Authorizes OAuth client scopes (browser-based)
- Configures service account domain-wide delegation (requires a step in Google Admin Console)
- Saves the customer ID and domain to your GAM config

After it completes, run `gam info domain` to verify the connection.

---

## Manual Setup

> For stepwise control or to troubleshoot a failed initialization. `Initialize GAM.ps1` performs all of these steps automatically.

### Installing GAM7

#### Option A: winget (Easiest on Windows)

```powershell
winget install --id GAM-Team.gam --accept-package-agreements --accept-source-agreements
```

This installs GAM7 to `C:\GAM7` and registers `gam` on your PATH. Restart your terminal after install.

#### Option B: MSI Installer

1. Download the latest MSI from the [GAM7 Releases](https://github.com/GAM-team/GAM/releases) page
2. Run the installer — it defaults to `C:\GAM7`
3. The installer will prompt you to begin setup

#### Option C: pip

```
pip install gam7
```

### 1. Create directories

```
mkdir C:\GAMConfig
mkdir C:\GAMWork
```

### 2. Set environment variables

Open **System Properties > Environment Variables** and add:

| Variable | Value |
|---|---|
| `GAMCFGDIR` | `C:\GAMConfig` |

Also add `C:\GAM7` to the system `Path`.

Restart your terminal after making these changes.

### 3. Initialize GAM

```
gam config drive_dir C:\GAMWork verify
```

This creates the config file at `C:\GAMConfig\gam.cfg`.

### 4. Create your GCP project

```
gam create project
```

This will:
- Prompt for your **Google Workspace admin email**
- Open a browser for Google authentication
- Create a GCP project and enable 23 Google APIs (Admin, Drive, Gmail, Calendar, etc.)
- Generate a service account with a private key
- Prompt you to create an **OAuth client ID** in the GCP Console:
  1. Go to the URL shown in the output
  2. Choose **Desktop App** for Application type
  3. Name it **GAM**
  4. Copy the **Client ID** and **Client Secret** back into the terminal

### 5. Authorize client (OAuth) scopes

```
gam oauth create
```

- Accept the default scope selections (press `c` to continue)
- Enter your admin email when prompted
- Complete the browser-based authorization flow

### 6. Authorize the service account (domain-wide delegation)

```
gam user your-admin@yourdomain.com update serviceaccount
```

- Accept the default scope selections (press `c` to continue)
- The first run will show all scopes as **FAIL** — this is expected
- GAM provides a link to the **Google Admin Console > Security > API Controls > Domain-wide Delegation** page
- Click the link, ensure **Overwrite existing client ID** is checked, and click **AUTHORIZE**
- Wait a few minutes, then verify:

```
gam user your-admin@yourdomain.com check serviceaccount
```

All scopes should show **PASS**.

### 7. Save basic config values

```
gam info domain
```

Note your **Customer ID** (e.g., `C01234567`) and **Primary Domain**, then:

```
gam config customer_id C01234567 domain yourdomain.com timezone local save verify
```

---

## Verifying the Connection

Test that GAM can reach your workspace:

```
# Show domain info
gam info domain

# List first 5 users
gam print users maxresults 5

# Show your own Drive file count
gam user your-admin@yourdomain.com show filecounts
```

If these commands return data, GAM is fully connected.

---

## Running Scripts

Scripts in this folder are **PowerShell wrappers** around GAM commands, run interactively from a technician workstation. They assume `gam` is on your system `Path`.

```powershell
# Example: Audit a shared folder's structure
.\Audit Shared Drive Folder.ps1 -UserEmail admin@yourdomain.com -FolderName "Shared Documents"
```

Each script includes comment-based help. Run `Get-Help .\ScriptName.ps1 -Full` for detailed usage.

---

## Useful GAM Commands Reference

### Drive — File Listing

```bash
# List all files in a user's Drive
gam user user@domain.com print filelist fields id,name,mimetype,size,owners.emailaddress

# List files in a specific folder (recursive)
gam user user@domain.com print filelist select drivefilename "Folder Name" fields id,name,mimetype,size,owners.emailaddress fullpath

# List files with permissions visible
gam user user@domain.com print filelist fields id,name,basicpermissions fullpath
```

### Drive — Disk Usage (folder-level stats)

```bash
# Full disk usage tree for a user's My Drive
gam user user@domain.com print diskusage mydrive

# Disk usage for a specific Shared Drive
gam user user@domain.com print diskusage shareddriveid 0AL5LiIe4dqxZUk9PVA

# Disk usage for a specific folder by name
gam user user@domain.com print diskusage drivefilename "Folder Name"
```

### Drive — Share Counts

```bash
# Show sharing breakdown (internal/external) for a user's files
gam user user@domain.com show filesharecounts

# Print sharing breakdown as CSV
gam user user@domain.com print filesharecounts
```

### Drive — File Tree

```bash
# Show folder tree structure
gam user user@domain.com show filetree select drivefilename "Folder Name" depth 2 fields id,mimetype

# Print file tree as CSV
gam user user@domain.com print filetree select drivefilename "Folder Name" fields id,mimetype
```

---

## Script Index

| Script | Purpose |
|---|---|
| [`Initialize GAM.ps1`](Initialize%20GAM.ps1) | One-time setup of GAM7 for a Google Workspace tenant: installs GAM, sets up directories and environment variables, creates a GCP project, authorizes OAuth and domain-wide delegation, and saves the customer config |
| [`Audit Shared Drive Folder.ps1`](Audit%20Shared%20Drive%20Folder.ps1) | Audits a Google Drive folder for subfolder counts, file counts, external ownership, external sharing, and total sizes — outputs CSV reports for migration planning |

---

## Resources

- [GAM7 Wiki (full documentation)](https://github.com/GAM-team/GAM/wiki)
- [GAM7 Drive Files Display](https://github.com/GAM-team/GAM/wiki/Users-Drive-Files-Display)
- [GAM7 Drive Permissions](https://github.com/GAM-team/GAM/wiki/Users-Drive-Permissions)
- [GAM7 Shared Drives](https://github.com/GAM-team/GAM/wiki/Shared-Drives)
- [GAM Discussion Group](https://groups.google.com/group/google-apps-manager)

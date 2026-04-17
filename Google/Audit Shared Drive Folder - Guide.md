# Audit Shared Drive Folder - Guide

Reference for running the audit script and interpreting each output file. Intended for the technician running the script and any specialist, analyst, or project engineer reviewing the results.

---

## Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Running the Script](#running-the-script)
  - [Parameters](#parameters)
  - [Examples](#examples)
- [What the Script Does](#what-the-script-does)
- [Output Files](#output-files)
  - [Summary.csv](#summarycsv)
  - [FolderDetails.csv](#folderdetailscsv)
  - [FileDetails.csv](#filedetailscsv)
  - [FolderTree.txt](#foldertreetxt)
- [Key Concepts](#key-concepts)
  - [Internal vs External](#internal-vs-external)
  - [Direct vs Recursive Counts](#direct-vs-recursive-counts)
  - [File Size Limitations](#file-size-limitations)
  - [Ownership vs Sharing](#ownership-vs-sharing)
- [Interpreting the Data](#interpreting-the-data)
- [Troubleshooting](#troubleshooting)

---

## Overview

`Audit Shared Drive Folder.ps1` uses [GAM7](https://github.com/GAM-team/GAM) to query the Google Drive API and produce four output files covering folder structure, file ownership, and external sharing across a Drive folder or Shared Drive. The outputs support multiple use cases: migration planning, security audits, and general Drive governance - anywhere you need to understand what is in a folder, who owns it, and who it is shared with.

The script produces two types of data:

- **GAM data** (Steps 1-2) - raw API results from Google covering folder sizes, file metadata, and permissions
- **Derived data** (Step 3) - PowerShell post-processing that classifies owners and share recipients as internal or external and aggregates counts per folder

All four output files land in the same timestamped directory.

---

## Prerequisites

- GAM7 installed and on the system PATH
- A customer workspace initialized under `C:\GAMConfig` (or a custom base dir)
- Run `Initialize GAM.ps1` first if the workspace has not been set up

See the [Google README](README.md) for full GAM setup instructions.

---

## Running the Script

The script can be run in two ways:

**Guided (recommended for first-time or occasional use)** - run with no arguments and the script prompts you for everything it needs:

```powershell
.\"Audit Shared Drive Folder.ps1"
```

The script will prompt for:

1. **Workspace selection** - lists initialized customer workspaces from `C:\GAMConfig` (or `-ConfigBaseDir`)
2. **Domain** - inferred from the selected workspace directory name; press Enter to accept or type a different value
3. **User email** - required if not passed as a parameter
4. **Folder identification** - choose between folder name, folder ID, or Shared Drive ID
5. **Folder disambiguation** - if a name search returns multiple matches, lists them with full paths and asks which one to audit

**Command-line arguments** - supply parameters directly to skip prompts, useful when running repeatedly or scripting the call:

```powershell
# By folder name (will search and prompt if multiple matches)
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderName "Active Members" -Domain contoso.com

# By folder ID (unambiguous - ID from the Drive URL)
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderId "1A2B3C4D5E6F" -Domain contoso.com

# Entire Shared Drive by its ID
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderId "0AL5LiIe4dqxZUk9PVA" -Domain contoso.com -IncludeSharedDrive

# Multiple internal domains (e.g. primary + alias)
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderId "1A2B3C4D5E6F" -Domain "contoso.com,contoso.net"

# Skip workspace selection prompt
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderId "1A2B3C4D5E6F" -Domain contoso.com -ConfigDir "C:\GAMConfig\contoso.com"
```

Any parameter not supplied on the command line will still be prompted for interactively, so you can supply as many or as few arguments as you like.

### Parameters

| Parameter | Required | Description |
|---|---|---|
| `-UserEmail` | Yes | Google Workspace email of a user with access to the folder. GAM impersonates this account via service account delegation. Typically an admin. |
| `-FolderName` | One of these | Name of the Drive folder to audit. If multiple folders share this name, the script will list them and ask you to choose. |
| `-FolderId` | One of these | Drive folder ID (from the URL: `drive.google.com/drive/folders/<ID>`). Preferred - avoids ambiguity with duplicate folder names. |
| `-Domain` | Yes | Primary domain of the Google Workspace tenant (e.g. `contoso.com`). Used to classify owners and share recipients as internal or external. For tenants with alias domains, pass all of them comma-separated: `"contoso.com,contoso.net"`. |
| `-IncludeSharedDrive` | No | When set, treats `-FolderId` as a Shared Drive ID and audits the entire drive. |
| `-OutputDir` | No | Directory to write output files to. Defaults to a timestamped subfolder under the current directory (`DriveAudit_yyyy-MM-dd_HHmmss`). |
| `-ConfigBaseDir` | No | Parent directory containing per-customer GAM config subdirectories. Defaults to `C:\GAMConfig`. |
| `-ConfigDir` | No | Full path to a specific customer GAM config directory. When provided, skips the workspace selection menu. |


### Examples

**Audit "Active Members" folder, let script prompt for everything else:**
```powershell
.\"Audit Shared Drive Folder.ps1"
```

**Audit a specific folder by ID (fastest, no ambiguity):**
```powershell
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderId "1A2B3C4D5E6F" -Domain contoso.com
```

**Audit an entire Shared Drive:**
```powershell
.\"Audit Shared Drive Folder.ps1" -UserEmail admin@contoso.com -FolderId "0AL5LiIe4dqxZUk9PVA" -Domain contoso.com -IncludeSharedDrive
```

---

## What the Script Does

The script runs three sequential steps. Steps 1 and 2 make API calls; Step 3 is pure PowerShell post-processing.

**Step 1 - Disk Usage** (`gam print diskusage`)

Walks the entire folder tree and returns one row per folder with GAM's authoritative counts: direct file count, direct folder count, direct file size, total file count, total folder count, and total file size. This is the structural backbone used by FolderTree.txt and Summary.csv.

**Step 2 - File Details** (`gam print filelist`)

Enumerates every file under the target folder with full path, owner email, size, MIME type, and permissions. This is the source of truth for all ownership and sharing classification in Step 3.

**Step 3 - Ownership and Sharing Analysis**

Post-processes FileDetails.csv in PowerShell to:
- Attribute each file to its containing folder using path matching
- Classify each file's owner as internal or external
- Classify each file's share recipients as internal users, external users, internal groups, external groups, or public
- Accumulate per-folder counts into the Summary hashtable
- Enrich FolderDetails.csv with those counts
- Generate Summary.csv (depth-0 rollup with cumulative totals)

No additional API calls are made in Step 3.

A **console transcript** is automatically saved to `Documents\GAM Logs\Audit-SharedDrive_<timestamp>.txt` for every run.

---

## Output Files

All files are written to the same output directory. The run banner at the end of the script lists which files were generated successfully.

---

### Summary.csv

**Purpose:** Start here. One row per top-level (depth-0) folder - the "A-E: 78 member folders" view. Gives a quick overview to scope work: how many member folders are in each group, how large is each group, and how much external ownership or sharing risk does each carry across the entire subtree. Useful for migration scoping, security reviews, and identifying which groups warrant closer attention.

In the Members shared drive context, depth-0 folders are the alphabetical group folders (A-E, F-J, K-O, P-T, U-Z). Each member organization lives one level below.

**One row per depth-0 folder**, sorted alphabetically by name.

> Requires FolderDetails.csv to be generated first. If FolderDetails.csv was not produced, Summary.csv will not be generated.

#### Columns

| Column | Source | What it means |
|---|---|---|
| `Group` | GAM | Folder name (e.g. "A-E", "F-J") |
| `MemberFolders` | GAM (authoritative) | Direct subfolders immediately inside this group folder - i.e. the number of member organizations in this group |
| `TotalFolders` | GAM | All subfolders at any depth below this group folder (recursive) |
| `TotalFiles` | GAM | All files at any depth below this group folder (recursive) |
| `TotalFileSizeBytes` | GAM | Bytes of all files at any depth (recursive, uploaded files only - see Key Concepts) |
| `TotalOwnedExternal` | Derived | Files with external owners **anywhere in the subtree** (all member folders combined) |
| `TotalSharedExternal` | Derived | Files shared externally **anywhere in the subtree** (all member folders combined) |

`TotalOwnedExternal` and `TotalSharedExternal` are summed from every subfolder under the group using ownership data derived from FileDetails.csv. Use these to compare risk levels across groups at a glance. For per-member folder detail, use FolderDetails.csv filtered by the group folder path. For the specific files driving these numbers, use FileDetails.csv.

---

### FolderDetails.csv

**Purpose:** Primary reference for data volume and migration risk per folder. Combines GAM's authoritative folder/file/size data with script-derived ownership and sharing counts in a single flat file.

**One row per folder** (including the root folder at depth -1 and a Trash entry if present).

#### Columns from GAM

| Column | What it means |
|---|---|
| `User` | The impersonated user email (same for all rows) |
| `name` | Folder name |
| `id` | Drive folder ID |
| `depth` | Depth in the tree. `-1` = the root folder being audited. `0` = top-level children. Increments by 1 per level. |
| `directFileCount` | Files stored directly in this folder (not in subfolders) |
| `directFolderCount` | Subfolders directly inside this folder |
| `directFileSize` | Bytes of files directly in this folder (see size note below) |
| `totalFileCount` | Files in this folder plus all descendants at every level |
| `totalFolderCount` | Subfolders at all levels below this folder |
| `totalFileSize` | Bytes of all files at all levels below this folder (see size note below) |
| `path` | Full Drive path (moved to last column for readability) |

> **Size columns reflect uploaded files only.** Google Workspace native files - Docs, Sheets, Slides, Forms, Sites, and Drawings - have no binary storage and report 0 bytes. Size columns will undercount the true migration scope for any folder that contains a significant proportion of native Google files. File counts are not affected.

> Note: The exact set and order of GAM columns may vary slightly by GAM version. The columns listed above are the ones the script references; additional columns may be present.

#### Columns added by the script (direct files in this folder only)

These columns count files that are **directly in this folder** - they do not include files in subfolders. For recursive totals, see `totalFileCount` (for file counts) or Summary.csv (for cumulative ownership/sharing rolled up across entire group subtrees).

| Column | What it means |
|---|---|
| `DirectFolders` | Copy of `directFolderCount` - included for proximity to the other direct-file columns |
| `OwnedInternal` | Direct files whose owner email is in the internal domain(s) |
| `OwnedExternal` | Direct files whose owner email is outside the internal domain(s). These may require ownership transfer before migration. |
| `SharedExternal` | Direct files shared with at least one external user, external domain, or public link. Includes all three categories. |
| `SharedWithGroupsInternal` | Direct files shared with at least one Google Group whose email is in the internal domain(s) |
| `SharedWithGroupsExternal` | Direct files shared with at least one Google Group outside the internal domain(s). These are also counted in `SharedExternal`. |
| `SharedWithUsers` | Direct files shared with at least one specific named user (internal or external) |

**`OwnedInternal + OwnedExternal` will not equal `directFileCount`** in general - the two owned columns are derived from FileDetails.csv while `directFileCount` comes from the Drive API. FileDetails.csv may be incomplete for very large folders or if permissions limit visibility.

---

### FileDetails.csv

**Purpose:** Row-level source of truth. Every file returned by GAM with its owner and all permissions. Used by the script internally for Step 3 post-processing and available for manual lookup when investigating specific files.

**One row per file** (folder entries from GAM are also present but filtered out during processing).

#### Columns from GAM

| Column | What it means |
|---|---|
| `id` | Drive file ID |
| `name` | File name |
| `mimeType` | MIME type (e.g. `application/vnd.google-apps.document` for Docs) |
| `size` | File size in bytes. Google Workspace native files (Docs, Sheets, etc.) report 0 - they have no binary size. |
| `owners.0.emailAddress` | Owner email address (column name may vary by GAM version) |
| `permissions.N.type` | Permission type for slot N: `user`, `group`, `domain`, or `anyone` |
| `permissions.N.emailAddress` | Email of the user or group for slot N (blank for `domain` and `anyone` types) |
| `permissions.N.domain` | Domain for slot N (present on `domain`-type permissions; may also be present on `group`) |
| `path.0` | Full Drive path to the file (column name may include additional numbered variants for alternate paths) |

Permission slots are numbered 0, 1, 2... with separate columns per property per slot. The number of slots varies by file. A file with three share recipients will have columns `permissions.0.*`, `permissions.1.*`, `permissions.2.*`.

**This is the file to open when you need to answer:** "Which specific files are externally owned or shared in this folder?"

---

### FolderTree.txt

**Purpose:** Human-readable hierarchical view of the folder structure with direct counts annotated per row. Good for a quick visual scan or for pasting into a status document.

**Format:** Indented text, one row per folder, sorted by full path within each depth level. Root folder appears in the header. Depth is represented by tab indentation.

**Annotation per row:** `(DirectFolders / DirectFiles / OwnedInternal / OwnedExternal / SharedExternal)`

All five numbers are **direct counts** - they count only files/folders immediately inside that folder, not descendants.

---

## Key Concepts

### Internal vs External

Every file owner and every share recipient is classified as **internal** or **external** based on the email domain:

- **Internal** - the email domain exactly matches one of the domains passed to `-Domain`
- **External** - the email domain does not match any domain in that list

This is an exact domain match, not substring matching. `user@contoso.com` is internal when `-Domain contoso.com` is set. `user@notcontoso.com` is external.

If the tenant has alias domains (e.g. `contoso.com` and `contoso.net` both route to the same tenant), pass all of them: `-Domain "contoso.com,contoso.net"`. Any domain not in the list is treated as external.

### Direct vs Recursive Counts

GAM provides both types natively in FolderDetails data:

| Term | Meaning | Example |
|---|---|---|
| **Direct** | Items stored immediately inside the folder, not in any subfolder | `directFileCount`, `directFolderCount` |
| **Recursive / Total** | Items at any depth below the folder, including all subfolders | `totalFileCount`, `totalFolderCount` |

The script-derived ownership and sharing columns (`OwnedInternal`, `OwnedExternal`, `SharedExternal`, etc.) are **direct** - they count files attributed to each specific folder, not descendants. The GAM `total*` columns in the same files are recursive.

### File Size Limitations

All size columns - `directFileSize`, `totalFileSize`, `DirectFileSize`, `TotalFileSize`, `TotalFileSizeBytes` - reflect **uploaded files only**. Google Workspace native files report 0 bytes because they are stored as metadata, not binary data:

- Google Docs
- Google Sheets
- Google Slides
- Google Forms
- Google Sites
- Google Drawings

For a Drive that is predominantly native Google files, the size columns may show a small fraction of the actual migration effort. File counts (`directFileCount`, `totalFileCount`, etc.) are not affected - native files are counted normally.

If an accurate size estimate is needed for migration tooling, export sizes must be estimated by multiplying file counts by an average exported file size, or by using a migration tool that reports converted sizes directly.

### Ownership vs Sharing

These are separate concepts and a file can be both:

- **Externally owned** - the file was created by (or transferred to) an account outside the tenant. External ownership does not prevent access by internal users if the file has been shared, but it can complicate migration because the external owner controls the file.
- **Externally shared** - the file has been shared with someone outside the tenant, an external domain, a public link, or an external Google Group. The file may be internally owned but still exposed externally.

A file can be internally owned and externally shared (common), or externally owned and internally shared (less common but happens when contractors have created files in shared folders).

---

## Interpreting the Data

### Answering common planning questions

**"How many member folders are in each group?"**
- Open `Summary.csv` - the `MemberFolders` column is the member count per group.

**"Which groups have the most data?"**
- Open `Summary.csv`, sort by `TotalFileSizeBytes` descending.

**"Which groups have the most external ownership or sharing risk?"**
- Open `Summary.csv`, sort by `TotalOwnedExternal` or `TotalSharedExternal` descending.

**"Which individual folders have the most external ownership risk?"**
- Open `FolderDetails.csv`, sort by `OwnedExternal` descending. Filter out depth -1 (root) and depth 0 (group) rows to focus on member folders.

**"Which specific files are externally owned?"**
- Open `FileDetails.csv`. Filter the `owners.0.emailAddress` column to rows where the domain is not your internal domain.

**"Is external sharing concentrated in a few folders or spread everywhere?"**
- Open `FolderDetails.csv`, sort by `SharedExternal` descending.

**"What is the total external risk across an entire group?"**
- Open `Summary.csv` - `TotalOwnedExternal` and `TotalSharedExternal` are already summed across every folder in the subtree.

**"I see a folder with high SharedExternal - what's actually shared?"**
- Cross-reference with `FileDetails.csv`. Filter by the folder path in the `path.0` column. Look at the `permissions.N.type` and `permissions.N.emailAddress` columns to see exactly who has access.

### Reading the FolderTree.txt

The annotation on each row is: `(DirectFolders / DirectFiles / OwnedInternal / OwnedExternal / SharedExternal)`

Example: `- AACSB International  (3 / 12 / 10 / 2 / 1)`
- 3 subfolders directly inside the folder
- 12 files directly inside the folder
- 10 of those files are internally owned
- 2 are externally owned
- 1 is shared externally

Descendant folders have their own rows with their own counts. Add up rows manually or open FolderDetails.csv filtered by path for totals.

---

## Troubleshooting

**Most or all ownership/sharing columns are zero**
- Check the console output (or transcript) for warnings about missing columns in FileDetails.csv
- Confirm the run banner did not report partial results
- Open FileDetails.csv and verify these column groups exist: `owners.*.emailaddress`, `permissions.N.type`, `permissions.N.emailaddress`

**Ownership counts don't add up to total file count**
- `OwnedInternal + OwnedExternal` reflects files visible in FileDetails.csv, not the GAM API total. FileDetails may be incomplete for very large folders or restricted files.

**Summary.csv was not generated**
- Requires FolderDetails.csv to succeed first. Check for FolderDetails warnings in the console output.

**FolderTree shows wrong hierarchy / folders in wrong order**
- The tree is sorted by full path, not by folder name alone. Folders with path characters in their names use longest-prefix matching to determine parent-child relationships.

**GAM folder count and FolderDetails DirectFolders differ**
- A warning is printed for each mismatch during the run. Trust GAM's `directFolderCount` as authoritative. The FileDetails-derived count may undercount if some folders had no visible files.

**"No folders named X were found"**
- Verify the folder is accessible to the `-UserEmail` account
- Try using `-FolderId` instead of `-FolderName` (paste the ID from the Drive URL)
- Confirm GAM has the correct scopes for the target workspace

**Script fails at the GAM step with a non-zero exit code**
- Run `gam info domain` in a terminal to confirm the workspace connection is healthy
- Run `gam user <email> show fileinfo <folderid>` to confirm folder-level access
- Review the GAM log at `%APPDATA%\GAM\logs\` for API-level errors

#!/usr/bin/env bash
# ==============================================================================
# .SYNOPSIS
#   Detects installed and active antivirus / EDR products on macOS.
#
# .DESCRIPTION
#   Scans for known third-party antivirus and EDR products by checking for:
#     1. Application bundles in /Applications and /Library
#     2. Daemon / launchd plists in /Library/LaunchDaemons
#     3. Running processes that match the product's main daemon
#
#   A product is reported as "Active" when its application/install footprint
#   is present AND its main background process is running. If no third-party
#   AV is found active, the script falls back to reporting the status of the
#   built-in Apple XProtect / XProtect Remediator engine.
#
#   The result is written to a NinjaOne custom device field
#   (default: installedAntivirus) and printed to stdout for activity logs.
#
# .NOTES
#   Designed for NinjaOne RMM deployment (SYSTEM / root level). Also runs
#   directly from a terminal with sudo.
#
#   Tested products:
#     BitDefender GravityZone, BitDefender Antivirus for Mac,
#     Sophos Endpoint, Sophos Home,
#     CrowdStrike Falcon, SentinelOne,
#     Microsoft Defender for Endpoint, Malwarebytes,
#     ESET Endpoint Security / Cyber Security, Webroot SecureAnywhere,
#     Norton / Symantec Endpoint Protection, McAfee Endpoint Security,
#     Trend Micro, Avast, AVG, Kaspersky,
#     Cortex XDR (Palo Alto), VMware Carbon Black,
#     Cylance, Trellix, F-Secure / WithSecure, Avira
#
#   Environment Variables (NinjaOne / RMM):
#     NINJA_FIELD_NAME  - (optional) Ninja custom field name to write the
#                         detected AV product into. Defaults to
#                         "installedAntivirus". Set to empty to skip.
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------------------
log_info()    { echo "[INFO]    $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_warn()    { echo "[WARN]    $*"; }
log_error()   { echo "[ERROR]   $*" >&2; }

# ------------------------------------------------------------------------------
# Root check (needed for reliable process and launchd inspection)
# ------------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root (sudo)."
    exit 1
fi

# ------------------------------------------------------------------------------
# Optional: Ninja custom field to write the result into
# ------------------------------------------------------------------------------
NINJA_FIELD_NAME="${NINJA_FIELD_NAME:-installedAntivirus}"
NINJA_CLI="/Applications/NinjaRMMAgent/programdata/ninjarmm-cli"

# Trap unexpected failures and write "Failed audit" to the Ninja field
trap 'log_error "Script failed unexpectedly."; [[ -f "${NINJA_CLI}" ]] && "${NINJA_CLI}" set "${NINJA_FIELD_NAME}" "Failed audit" 2>/dev/null; exit 1' ERR

# ------------------------------------------------------------------------------
# Snapshot of running processes - one ps call, reused for every product
# ------------------------------------------------------------------------------
PROCESS_LIST=$(ps -axco command 2>/dev/null || true)
PROCESS_LIST_FULL=$(ps -axo command 2>/dev/null || true)

# ==============================================================================
# Detection helpers
# ==============================================================================

# path_exists: returns 0 if any of the supplied paths exists
path_exists() {
    local p
    for p in "$@"; do
        if [[ -e "$p" ]]; then return 0; fi
    done
    return 1
}

# process_running: returns 0 if any of the supplied process names is running
# Matches against both the short command name and the full command line so
# bundle helpers like "com.crowdstrike.falcon.Agent" are caught.
process_running() {
    local name
    for name in "$@"; do
        if echo "$PROCESS_LIST" | grep -qiE "(^|/)${name}( |$)"; then return 0; fi
        if echo "$PROCESS_LIST_FULL" | grep -qiF "$name"; then return 0; fi
    done
    return 1
}

# ==============================================================================
# Product matrix
# Each check returns a status of "Active", "Installed (Inactive)" or "" (none).
# Format used for active products in output: "Product Name"
# ==============================================================================

declare -a INSTALLED_PRODUCTS=()
declare -a ACTIVE_PRODUCTS=()

record() {
    local name="$1" state="$2"
    if [[ "$state" == "Active" ]]; then
        ACTIVE_PRODUCTS+=("$name")
        INSTALLED_PRODUCTS+=("$name (Active)")
    elif [[ "$state" == "Installed" ]]; then
        INSTALLED_PRODUCTS+=("$name (Installed, Inactive)")
    fi
}

check_product() {
    # $1 = friendly name
    # $2 = "|" delimited list of paths to check
    # $3 = "|" delimited list of process names to check
    local name="$1"
    local paths_str="$2"
    local procs_str="$3"

    local IFS='|'
    # shellcheck disable=SC2206
    local paths=($paths_str)
    # shellcheck disable=SC2206
    local procs=($procs_str)
    unset IFS

    if path_exists "${paths[@]}"; then
        if process_running "${procs[@]}"; then
            record "$name" "Active"
        else
            record "$name" "Installed"
        fi
    fi
}

# ==============================================================================
# Third-party AV / EDR checks
# ==============================================================================
log_info "Scanning for installed antivirus / EDR products..."

# BitDefender GravityZone (business endpoint)
check_product "BitDefender GravityZone" \
    "/Library/Bitdefender/AVP|/Applications/Endpoint Security for Mac.app" \
    "BDLDaemon|EndpointSecurityforMac|bdldaemon"

# BitDefender Antivirus for Mac (consumer)
check_product "BitDefender Antivirus for Mac" \
    "/Applications/Bitdefender/AntivirusforMac.app|/Applications/Bitdefender Virus Scanner.app" \
    "AntivirusforMac|BitdefenderVirusScanner"

# Sophos Endpoint / Sophos Home
check_product "Sophos Endpoint" \
    "/Library/Sophos Anti-Virus|/Applications/Sophos/Sophos Endpoint.app|/Applications/Sophos Endpoint.app" \
    "SophosScanD|SophosAntiVirus|Sophos Endpoint|SophosAgent"

# CrowdStrike Falcon
check_product "CrowdStrike Falcon" \
    "/Applications/Falcon.app|/Library/CS" \
    "falconctl|com.crowdstrike.falcon.Agent|falcond"

# SentinelOne
check_product "SentinelOne" \
    "/Library/Sentinel|/Applications/SentinelOne|/Applications/SentinelOne Extensions.app" \
    "sentineld|SentinelAgent|com.sentinelone.sentineld"

# Microsoft Defender for Endpoint
check_product "Microsoft Defender for Endpoint" \
    "/Applications/Microsoft Defender.app|/Applications/Microsoft Defender ATP.app|/Library/Application Support/Microsoft/Defender" \
    "wdavdaemon|Microsoft Defender|wdavdaemon_enterprise"

# Malwarebytes
check_product "Malwarebytes" \
    "/Applications/Malwarebytes.app|/Library/Application Support/Malwarebytes" \
    "RTProtectionDaemon|Malwarebytes|FrontendAgent"

# ESET Endpoint Security / Cyber Security
check_product "ESET" \
    "/Applications/ESET Endpoint Security.app|/Applications/ESET Cyber Security.app|/Applications/ESET Cyber Security Pro.app|/Library/Application Support/ESET" \
    "esets_daemon|esets_proxy|ESET Endpoint Security|esets_ctl"

# Webroot SecureAnywhere
check_product "Webroot SecureAnywhere" \
    "/Applications/Webroot SecureAnywhere.app|/Library/Application Support/Webroot" \
    "WSDaemon|WRSAMacApp|Webroot SecureAnywhere"

# Norton / Symantec Endpoint Protection
check_product "Norton / Symantec Endpoint Protection" \
    "/Applications/Norton 360.app|/Applications/Symantec Solutions|/Library/Application Support/Symantec" \
    "SymDaemon|Symantec|NortonSecurity|navx"

# McAfee Endpoint Security for Mac
check_product "McAfee Endpoint Security" \
    "/Applications/McAfee Endpoint Security for Mac.app|/Library/McAfee" \
    "McAfeeReporter|masvc|VShieldScanner|McAfeeSystemExtensions"

# Trend Micro
check_product "Trend Micro" \
    "/Applications/Trend Micro Security.app|/Library/Application Support/TrendMicro" \
    "iCoreService|TrendMicro|tmccli"

# Avast Security
check_product "Avast Security" \
    "/Applications/Avast Security.app|/Library/Application Support/Avast" \
    "AvastSecurity|com.avast.daemon|AvastFileShield"

# AVG AntiVirus
check_product "AVG AntiVirus" \
    "/Applications/AVG AntiVirus.app|/Library/Application Support/AVG" \
    "AVGAntiVirus|com.avg.daemon"

# Kaspersky
check_product "Kaspersky" \
    "/Applications/Kaspersky.app|/Applications/Kaspersky Anti-Virus For Mac.app|/Library/Application Support/Kaspersky Lab" \
    "kav|Kaspersky|kavd"

# Cortex XDR (Palo Alto Networks)
check_product "Cortex XDR" \
    "/Applications/Cortex XDR.app|/Library/Application Support/PaloAltoNetworks/Traps" \
    "cyserver|cyveraservice|com.paloaltonetworks.cortex"

# VMware / Broadcom Carbon Black
check_product "Carbon Black" \
    "/Applications/CarbonBlack|/Applications/Confer.app|/Library/Application Support/com.vmware.carbonblack.cloud" \
    "CbDefense|RepMgr|RepWAV|RepUx"

# Cylance / BlackBerry Protect
check_product "Cylance" \
    "/Applications/Cylance|/Applications/CylancePROTECT.app|/Library/Application Support/Cylance" \
    "CylanceSvc|CylanceUI"

# Trellix Endpoint Security (post-McAfee/FireEye merger)
check_product "Trellix Endpoint Security" \
    "/Applications/Trellix Endpoint Security for Mac.app|/Library/Trellix" \
    "TrellixSystemExtensions|TrellixHelper"

# F-Secure / WithSecure
check_product "WithSecure (F-Secure)" \
    "/Applications/F-Secure|/Applications/WithSecure|/Library/Application Support/F-Secure" \
    "fshoster|F-Secure|WithSecure"

# Avira Security for Mac
check_product "Avira" \
    "/Applications/Avira Security.app|/Applications/Avira Antivirus Pro.app|/Library/Application Support/Avira" \
    "Avira.ServiceHost|avira_daemon|AviraDaemon"

# ==============================================================================
# Build result string
# ==============================================================================
RESULT=""

if [[ "${#ACTIVE_PRODUCTS[@]}" -gt 0 ]]; then
    # Join active products with ", "
    RESULT=$(printf "%s, " "${ACTIVE_PRODUCTS[@]}")
    RESULT="${RESULT%, }"
else
    # ----------------------------------------------------------------------
    # Fall back to Apple XProtect / XProtect Remediator
    # XProtect is built-in to all modern macOS releases. We report version
    # and last update timestamp so the field reflects something meaningful.
    # ----------------------------------------------------------------------
    log_info "No active third-party antivirus detected. Checking XProtect..."

    XPROTECT_PLIST="/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist"
    XPROTECT_REMEDIATOR_APP="/Library/Apple/System/Library/CoreServices/XProtect.app"

    XPROTECT_VERSION=""
    XPROTECT_DATE=""

    if [[ -f "$XPROTECT_PLIST" ]]; then
        XPROTECT_VERSION=$(/usr/bin/defaults read "$XPROTECT_PLIST" Version 2>/dev/null || true)
        # Last modification date as the most reliable "last updated" signal
        XPROTECT_DATE=$(/bin/date -r "$XPROTECT_PLIST" "+%Y-%m-%d" 2>/dev/null || true)
    fi

    REMEDIATOR_PRESENT="No"
    if [[ -d "$XPROTECT_REMEDIATOR_APP" ]]; then
        REMEDIATOR_PRESENT="Yes"
    fi

    if [[ -n "$XPROTECT_VERSION" ]]; then
        RESULT="Apple XProtect (v${XPROTECT_VERSION}, updated ${XPROTECT_DATE})"
    else
        RESULT="Apple XProtect (status unknown)"
    fi

    if [[ "$REMEDIATOR_PRESENT" == "Yes" ]]; then
        RESULT="${RESULT} + XProtect Remediator"
    fi
fi

# ==============================================================================
# Output summary
# ==============================================================================
echo ""
echo "============================================================"
echo "Antivirus / EDR Detection"
echo "============================================================"
if [[ "${#INSTALLED_PRODUCTS[@]}" -gt 0 ]]; then
    echo "Detected products:"
    for p in "${INSTALLED_PRODUCTS[@]}"; do
        echo "  - $p"
    done
else
    echo "No third-party antivirus or EDR products detected."
fi
echo "------------------------------------------------------------"
echo "Reported value: ${RESULT}"
echo "============================================================"

# ==============================================================================
# Write to NinjaOne custom field
# ==============================================================================
if [[ -n "$NINJA_FIELD_NAME" ]]; then
    if [[ -f "$NINJA_CLI" ]]; then
        if "$NINJA_CLI" set "$NINJA_FIELD_NAME" "$RESULT" 2>/dev/null; then
            log_success "Wrote '${RESULT}' to Ninja field '${NINJA_FIELD_NAME}'."
        else
            log_warn "Could not write to Ninja field '${NINJA_FIELD_NAME}'."
        fi
    else
        log_warn "ninjarmm-cli not found at ${NINJA_CLI} - skipping Ninja field write."
    fi
fi

exit 0

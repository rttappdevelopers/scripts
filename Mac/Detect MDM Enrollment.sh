#!/usr/bin/env bash
# ==============================================================================
# .SYNOPSIS
#   Detects whether this Mac is enrolled in an MDM, and identifies which one.
#
# .DESCRIPTION
#   Queries macOS profile enrollment status, configuration profile identifiers,
#   MDM server URLs, and filesystem artifacts to determine:
#     1. Whether the device is enrolled in any MDM
#     2. Which MDM vendor is managing the device (if identifiable)
#     3. Whether enrollment is DEP/ADE supervised or user-approved
#
#   Detection uses a tiered approach:
#     Tier 1 - profiles status (enrollment yes/no, DEP vs user-approved)
#     Tier 2 - profileServerURL from installed profiles (most definitive)
#     Tier 3 - profileIdentifier prefix matching (vendor-controlled strings)
#     Tier 4 - Filesystem artifact fallbacks (work without root in some cases)
#
#   Outputs a plain-text summary suitable for NinjaOne activity logs.
#   Optionally writes the detected MDM name to a Ninja custom field.
#
# .NOTES
#   Must run as root (sudo) — profiles -C -v requires root.
#   Designed for NinjaOne RMM deployment (SYSTEM level / MDM script).
#
#   Tested MDM platforms:
#     NinjaOne, Jamf Pro/Now, Mosyle, JumpCloud, Microsoft Intune,
#     Kandji, Addigy, Cisco Meraki SM, VMware Workspace ONE / AirWatch,
#     Hexnode, ManageEngine MDM Plus, Scalefusion, SimpleMDM,
#     Miradore, Rippling, Apple Business Essentials, Ivanti/MobileIron,
#     BlackBerry UEM, Jamf School, FileWave
#
#   Environment Variables (NinjaOne / RMM):
#     NINJA_FIELD_NAME  - (optional) Ninja custom field name to write the
#                         detected MDM name into. Leave unset to skip.
#                         Example: enrolledMDM
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------------------
log_info()    { echo "[INFO]    $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_warn()    { echo "[WARN]    $*"; }
log_error()   { echo "[ERROR]   $*" >&2; }

# ------------------------------------------------------------------------------
# Root check
# ------------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root (sudo)."
    exit 1
fi

# ------------------------------------------------------------------------------
# Optional: Ninja custom field to write the result into
# ------------------------------------------------------------------------------
NINJA_FIELD_NAME="${NINJA_FIELD_NAME:-enrolledMDM}"

# ==============================================================================
# TIER 1 — Enrollment status
# ==============================================================================
log_info "Checking MDM enrollment status..."

ENROLLMENT_OUTPUT=$(profiles status -type enrollment 2>/dev/null || true)
MDM_ENROLLED=$(echo "$ENROLLMENT_OUTPUT" | awk -F': ' '/MDM enrollment/{print $2}' | xargs)
DEP_ENROLLED=$(echo "$ENROLLMENT_OUTPUT" | awk -F': ' '/Enrolled via DEP/{print $2}' | xargs)

log_info "MDM enrollment raw: '${MDM_ENROLLED}'"
log_info "DEP enrollment raw: '${DEP_ENROLLED}'"

# Normalise to true/false (use tr for macOS bash 3.2 compatibility — no ,, operator)
MDM_ENROLLED_LOWER=$(echo "$MDM_ENROLLED" | tr '[:upper:]' '[:lower:]')
DEP_ENROLLED_LOWER=$(echo "$DEP_ENROLLED" | tr '[:upper:]' '[:lower:]')

case "$MDM_ENROLLED_LOWER" in
    yes*) IS_ENROLLED=true ;;
    *)    IS_ENROLLED=false ;;
esac

case "$DEP_ENROLLED_LOWER" in
    yes*) IS_DEP=true ;;
    *)    IS_DEP=false ;;
esac

if [[ "$IS_ENROLLED" == "false" ]]; then
    log_info "Device does not appear to be enrolled in any MDM."
    echo ""
    echo "============================================================"
    echo "MDM Enrollment Status : NOT ENROLLED"
    echo "============================================================"

    if [[ -n "$NINJA_FIELD_NAME" ]]; then
        /Applications/NinjaRMMAgent/programdata/ninjarmm-cli set "$NINJA_FIELD_NAME" "Not Enrolled" 2>/dev/null || \
            log_warn "Could not write to Ninja field '${NINJA_FIELD_NAME}'."
    fi
    exit 0
fi

# ==============================================================================
# TIER 2 — Pull full profile data (requires root)
# ==============================================================================
log_info "Gathering installed configuration profiles..."
ALL_PROFILES=$(profiles -C -v 2>/dev/null || true)

if [[ -z "$ALL_PROFILES" ]]; then
    log_warn "profiles -C -v returned no output. Falling through to filesystem checks."
fi

# Extract the MDM server URL — most definitive single field
# profiles -C -v format: '   attribute: profileServerURL: https://...'
# Split on ': ' gives: $1=attribute, $2=profileServerURL, $3=value (may contain colons in URL)
SERVER_URL=$(echo "$ALL_PROFILES" | awk '/profileServerURL/{sub(/.*profileServerURL: /,""); print; exit}' | xargs)
log_info "MDM Server URL: '${SERVER_URL:-<not found>}'"

# ==============================================================================
# TIER 3 — profileIdentifier + serverURL pattern matching
# ==============================================================================
DETECTED_MDM="Unknown"

detect_by_patterns() {
    local profiles_data="$1"
    local server_url="$2"
    local combined="${profiles_data} ${server_url}"

    # ---- NinjaOne MDM -------------------------------------------------------
    # Match only MDM-specific identifiers and server URLs, NOT just any mention
    # of ninjaone/ninjarmm — the RMM agent may push non-MDM profiles (e.g.
    # Huntress, ConnectSecure) that reference ninjaone in their identifiers.
    # com.ninjaone.profile.mdm  = the MDM enrollment profile (definitive)
    # com.ninjaone.mdm.*        = MDM payload profiles
    # ninjarmm.com / ninjaone.com in the SERVER_URL = MDM server
    if echo "$profiles_data" | grep -qiE "com\.ninjaone\.profile\.mdm|com\.ninjaone\.mdm\."; then
        echo "NinjaOne"; return
    fi
    if echo "$server_url" | grep -qiE "ninjarmm\.com|ninjaone\.com"; then
        echo "NinjaOne"; return
    fi

    # ---- Jamf Pro / Jamf Now / Jamf School ----------------------------------
    # Filesystem check is high-confidence and doesn't need profile data
    if [[ -f /usr/local/jamf/bin/jamf ]]; then
        echo "Jamf"; return
    fi
    if echo "$combined" | grep -qiE "jamfcloud\.com|com\.jamfsoftware\.|com\.jamf\.|jamfnow\.com|jamfschool\.com"; then
        echo "Jamf"; return
    fi

    # ---- Mosyle (Business / Manager / Auth / Fusion) ------------------------
    if echo "$combined" | grep -qiE "com\.mosyle\.|io\.mosyle\.|mosyle\.com"; then
        echo "Mosyle"; return
    fi

    # ---- JumpCloud ----------------------------------------------------------
    if [[ -f /opt/jc/bin/jumpcloud-agent ]]; then
        echo "JumpCloud"; return
    fi
    if echo "$combined" | grep -qiE "com\.jumpcloud\.|jumpcloud\.com"; then
        echo "JumpCloud"; return
    fi

    # ---- Microsoft Intune / Endpoint Manager --------------------------------
    if [[ -d /Library/Intune ]]; then
        echo "Microsoft Intune"; return
    fi
    if echo "$combined" | grep -qiE "manage\.microsoft\.com|com\.microsoft\.intune|com\.microsoft\.mdm|com\.microsoft\.enterprise"; then
        echo "Microsoft Intune"; return
    fi

    # ---- Kandji -------------------------------------------------------------
    if [[ -d /Library/Kandji ]]; then
        echo "Kandji"; return
    fi
    if echo "$combined" | grep -qiE "io\.kandji\.|kandji\.io"; then
        echo "Kandji"; return
    fi

    # ---- Addigy -------------------------------------------------------------
    if [[ -d /Library/Addigy ]]; then
        echo "Addigy"; return
    fi
    if echo "$combined" | grep -qiE "com\.addigy\.|io\.addigy\.|addigy\.com"; then
        echo "Addigy"; return
    fi

    # ---- Cisco Meraki Systems Manager ---------------------------------------
    if echo "$combined" | grep -qiE "com\.meraki\.|com\.cisco\.meraki\.|meraki\.com"; then
        echo "Cisco Meraki Systems Manager"; return
    fi

    # ---- VMware Workspace ONE / AirWatch / Omnissa --------------------------
    if echo "$combined" | grep -qiE "com\.air-watch\.|com\.airwatch\.|com\.vmware\.mdm\.|com\.vmware\.airwatch\.|com\.omnissa\.|awmdm\.com|airwatchportals\.com|omnissa\.com"; then
        echo "VMware Workspace ONE (AirWatch)"; return
    fi

    # ---- Hexnode -------------------------------------------------------------
    if echo "$combined" | grep -qiE "com\.hexnode\.|hexnode\.com"; then
        echo "Hexnode"; return
    fi

    # ---- ManageEngine MDM Plus ----------------------------------------------
    if echo "$combined" | grep -qiE "com\.manageengine\.|com\.zohocorp\.|mdmcloud\.com|manageengine\.com"; then
        echo "ManageEngine MDM Plus"; return
    fi

    # ---- Scalefusion (fka MobiLock) -----------------------------------------
    if echo "$combined" | grep -qiE "com\.scalefusion\.|io\.scalefusion\.|com\.mobilock\.|scalefusion\.com"; then
        echo "Scalefusion"; return
    fi

    # ---- SimpleMDM ----------------------------------------------------------
    if echo "$combined" | grep -qiE "com\.simplemdm\.|net\.simplemdm\.|simplemdm\.com"; then
        echo "SimpleMDM"; return
    fi

    # ---- Miradore -----------------------------------------------------------
    if echo "$combined" | grep -qiE "com\.miradore\.|miradore\.com"; then
        echo "Miradore"; return
    fi

    # ---- Rippling -----------------------------------------------------------
    if echo "$combined" | grep -qiE "com\.rippling\.|rippling\.com"; then
        echo "Rippling"; return
    fi

    # ---- Apple Business Essentials (Fleetsmith) -----------------------------
    if echo "$combined" | grep -qiE "com\.fleetsmith\.|businessessentials\.apple\.com"; then
        echo "Apple Business Essentials"; return
    fi

    # ---- Ivanti (fka MobileIron) --------------------------------------------
    if echo "$combined" | grep -qiE "com\.mobileiron\.|com\.ivanti\.|mobileiron\.com|ivanti\.com"; then
        echo "Ivanti (MobileIron)"; return
    fi

    # ---- BlackBerry UEM -----------------------------------------------------
    if echo "$combined" | grep -qiE "com\.blackberry\.|com\.good\.|blackberry\.com|bbcs\.net"; then
        echo "BlackBerry UEM"; return
    fi

    # ---- FileWave -----------------------------------------------------------
    if echo "$combined" | grep -qiE "com\.filewave\.|filewave\.com"; then
        echo "FileWave"; return
    fi

    # ---- Enrolled but vendor unrecognised -----------------------------------
    echo "Unknown (enrolled)"
}

DETECTED_MDM=$(detect_by_patterns "$ALL_PROFILES" "$SERVER_URL")

# ==============================================================================
# TIER 4 — Filesystem fallbacks (fill in "Unknown" cases where we can)
# ==============================================================================
if [[ "$DETECTED_MDM" == "Unknown (enrolled)" ]]; then
    log_info "Profile pattern matching inconclusive — trying filesystem fallbacks..."

    if   [[ -f /usr/local/jamf/bin/jamf        ]]; then DETECTED_MDM="Jamf"
    elif [[ -d /Library/Kandji                  ]]; then DETECTED_MDM="Kandji"
    elif [[ -f /opt/jc/bin/jumpcloud-agent      ]]; then DETECTED_MDM="JumpCloud"
    elif [[ -d /Library/Mosyle                  ]]; then DETECTED_MDM="Mosyle"
    elif [[ -d /Library/Intune                  ]]; then DETECTED_MDM="Microsoft Intune"
    elif [[ -d /Library/Addigy                  ]]; then DETECTED_MDM="Addigy"
    fi
fi

# ==============================================================================
# Collect profile identifiers for display
# ==============================================================================
PROFILE_IDS=$(echo "$ALL_PROFILES" | awk '/attribute: profileIdentifier:/{sub(/.*profileIdentifier: /,""); print "  - " $0}' | sort -u)
PROFILE_COUNT=$(profiles -C 2>/dev/null | grep -c "attribute: profileIdentifier" || echo "unknown")

# ==============================================================================
# Build enrollment type string
# ==============================================================================
if [[ "$IS_DEP" == "true" ]]; then
    ENROLLMENT_TYPE="DEP / ADE (Supervised)"
elif [[ "$MDM_ENROLLED_LOWER" == *"user approved"* ]]; then
    ENROLLMENT_TYPE="User Approved (BYOD)"
else
    ENROLLMENT_TYPE="Yes (type undetermined)"
fi

# ==============================================================================
# Output summary
# ==============================================================================
echo ""
echo "============================================================"
echo "MDM Enrollment Status : ENROLLED"
echo "Enrollment Type       : ${ENROLLMENT_TYPE}"
echo "Detected MDM          : ${DETECTED_MDM}"
echo "MDM Server URL        : ${SERVER_URL:-<not found in profiles>}"
echo "Profile Count         : ${PROFILE_COUNT}"
echo "------------------------------------------------------------"
echo "Profile Identifiers:"
if [[ -n "$PROFILE_IDS" ]]; then
    echo "$PROFILE_IDS"
else
    echo "  <none found>"
fi
echo "============================================================"

# ==============================================================================
# Optional: Write to NinjaOne custom field
# ==============================================================================
if [[ -n "$NINJA_FIELD_NAME" ]]; then
    NINJA_CLI="/Applications/NinjaRMMAgent/programdata/ninjarmm-cli"
    if [[ -f "$NINJA_CLI" ]]; then
        "$NINJA_CLI" set "$NINJA_FIELD_NAME" "$DETECTED_MDM" 2>/dev/null && \
            log_info "Wrote '${DETECTED_MDM}' to Ninja field '${NINJA_FIELD_NAME}'." || \
            log_warn "Could not write to Ninja field '${NINJA_FIELD_NAME}'."
    else
        log_warn "ninjarmm-cli not found — skipping Ninja field write."
    fi
fi

exit 0

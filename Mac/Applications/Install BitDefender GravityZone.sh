#!/bin/bash

# Description: Download and install BitDefender Endpoint Security for Mac from GravityZone.
# This script is designed for silent deployment via RMM tools (e.g., NinjaRMM).
# It automatically detects the macOS architecture (Intel/ARM) and downloads
# the appropriate BitDefender offline installer package.
#
# Requires:
# - 'bitdefenderMacLinPackage' variable: This should be provided by your RMM
#   (e.g., ninjarmm-cli get bitdefenderMacLinPackage) and contain the unique
#   BitDefender package ID from your GravityZone portal.
# - Root privileges: The script must be executed with 'sudo' or as the root user
#   to perform system-level installations.
#
# Key improvements in this version:
# - Enhanced error handling: Uses 'set -euo pipefail' and explicit checks.
# - Temporary directory management: Creates and cleans up a unique temporary
#   directory for downloads and mounted DMGs.
# - Robust DMG mounting: Directly uses and verifies the specified mount point.
# - Silent operations: Uses 'curl -s' and 'hdiutil -nobrowse -quiet'.
# - Unified installation: Both ARM (Apple Silicon) and Intel now use the
#   full offline DMG containing a direct .pkg installer for silent deployment.

# --- Configuration & Pre-checks ---

# Enable strict error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status.
set -euo pipefail

# Get the BitDefender package ID from NinjaRMM custom field.
bitdefenderMacLinPackage=$(/Applications/NinjaRMMAgent/programdata/ninjarmm-cli get bitdefenderMacLinPackage)

# Validate the package ID format. Allow alphanumeric characters, hyphens, underscores, and common symbols.
if [[ -z "$bitdefenderMacLinPackage" || ! "$bitdefenderMacLinPackage" =~ ^[a-zA-Z0-9+/=_-]+$ ]]; then
    echo "ERROR: Environment variable 'bitdefenderMacLinPackage' is not set or not in the correct format." >&2
    echo "Provided value: '$bitdefenderMacLinPackage'" >&2
    exit 1
fi

# Check for root privileges. The installer requires root.
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run with root privileges (e.g., using 'sudo')." >&2
    exit 1
fi

# Create a unique temporary directory for all operations.
# This ensures isolation and simplifies cleanup.
TEMP_DIR=$(mktemp -d "/tmp/bitdefender_install_XXXXXX")
if [[ ! -d "$TEMP_DIR" ]]; then
    echo "ERROR: Failed to create temporary directory: $TEMP_DIR" >&2
    exit 1
fi
echo "Created temporary directory: $TEMP_DIR"

# Define the expected mount point within the temporary directory
MOUNT_POINT="$TEMP_DIR/BDMount"

# Define a cleanup function to be executed on script exit (success or failure).
cleanup_on_exit() {
    echo "Initiating cleanup process..."
    # Attempt to detach the DMG if it was mounted
    if [[ -n "${MOUNT_POINT:-}" && -d "$MOUNT_POINT" ]]; then
        echo "Attempting to unmount DMG at: $MOUNT_POINT"
        # Use '|| true' to prevent the trap from failing if unmount fails (e.g., already unmounted)
        hdiutil detach "$MOUNT_POINT" -quiet || true
    fi
    # Remove the temporary directory
    if [[ -d "$TEMP_DIR" ]]; then
        echo "Removing temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
    echo "Cleanup complete."
}

# Set up a trap to call the cleanup function when the script exits.
trap cleanup_on_exit EXIT

# Change to the temporary directory. All downloads and operations will happen here.
cd "$TEMP_DIR" || { echo "ERROR: Failed to change to temporary directory: $TEMP_DIR"; exit 1; }

# --- Determine Architecture and Download URL ---

macArchitecture=$(uname -m)
BITDEFENDER_URL=""
BITDEFENDER_FILE_NAME=""

if [[ "$macArchitecture" == "arm64" ]]; then
    echo "Detected ARM64 architecture (Apple Silicon)."
    BITDEFENDER_URL="https://cloud.gravityzone.bitdefender.com/Packages/MAC/0/$bitdefenderMacLinPackage/Bitdefender_for_MAC_ARM.dmg"
    BITDEFENDER_FILE_NAME="Bitdefender_for_MAC_ARM.dmg"
else
    echo "Detected Intel architecture."
    # Using the full offline installation kit for Intel as well.
    BITDEFENDER_URL="https://cloud.gravityzone.bitdefender.com/Packages/MAC/0/$bitdefenderMacLinPackage/Bitdefender_for_MAC.dmg"
    BITDEFENDER_FILE_NAME="Bitdefender_for_MAC.dmg"
fi

echo "BitDefender download URL: $BITDEFENDER_URL"
echo "Expected file name: $BITDEFENDER_FILE_NAME"

# --- Download the Installer ---

echo "Downloading '$BITDEFENDER_FILE_NAME'..."
# curl options:
# -s: Silent mode (no progress bar or error messages)
# -L: Follow HTTP redirects
# -o: Write output to a specified file
curl -s -L -o "$BITDEFENDER_FILE_NAME" "$BITDEFENDER_URL"
if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to download '$BITDEFENDER_FILE_NAME' from '$BITDEFENDER_URL'." >&2
    exit 1
fi
echo "Download complete: '$BITDEFENDER_FILE_NAME'"

# --- Mount the DMG File ---

echo "Mounting '$BITDEFENDER_FILE_NAME' to '$MOUNT_POINT'..."
# hdiutil options:
# -nobrowse: Prevents the mounted volume from appearing in Finder sidebar or desktop.
# -quiet: Suppresses verbose output.
# -noverify: Skips disk image verification (speeds up, but less safe if source is untrusted).
# -mountpoint: Specifies a custom mount point within our temporary directory.
hdiutil attach -nobrowse -quiet -noverify -mountpoint "$MOUNT_POINT" "$BITDEFENDER_FILE_NAME"
HDIUTIL_EXIT_CODE=$? # Capture exit code immediately after the command

if [[ "$HDIUTIL_EXIT_CODE" -ne 0 ]]; then
    echo "ERROR: hdiutil attach failed with exit code $HDIUTIL_EXIT_CODE." >&2
    exit 1
fi

# Verify that the mount point exists and is a directory after attachment
if [[ ! -d "$MOUNT_POINT" ]]; then
    echo "ERROR: DMG mounted successfully but mount point '$MOUNT_POINT' does not exist or is not a directory." >&2
    echo "Please check hdiutil output for errors if any." >&2
    exit 1
fi
echo "DMG mounted successfully at: $MOUNT_POINT"

# --- Install BitDefender ---

echo "Starting BitDefender installation process using PKG installer..."
INSTALL_SUCCESS=false

# For both ARM and Intel, we now expect a direct .pkg installer inside the DMG.
# Find the first .pkg file in the mounted volume (maxdepth 2 to prevent deep searches).
PKG_PATH=$(find "$MOUNT_POINT" -maxdepth 2 -name "*.pkg" -print -quit)
if [[ -z "$PKG_PATH" ]]; then
    echo "ERROR: Could not find a .pkg installer inside the mounted DMG at '$MOUNT_POINT'." >&2
    exit 1
fi
echo "Found PKG installer: '$PKG_PATH'"

# Execute the .pkg installer silently.
# 'installer -pkg <package_path> -target /' installs to the root volume.
sudo installer -pkg "$PKG_PATH" -target /
if [[ $? -eq 0 ]]; then
    echo "BitDefender PKG installation successful."
    INSTALL_SUCCESS=true
else
    echo "ERROR: BitDefender PKG installation failed." >&2
fi

# --- Final Status ---

if $INSTALL_SUCCESS; then
    echo "BitDefender installation process completed successfully."
    exit 0
else
    echo "BitDefender installation process completed with errors."
    exit 1
fi

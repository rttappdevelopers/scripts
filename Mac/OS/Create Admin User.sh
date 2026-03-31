#!/usr/bin/env bash
#
# Description: Creates a hidden local admin user on macOS.
#   Pulls username and password from NinjaOne environment variables / custom fields,
#   or prompts the technician interactively if run outside RMM.
#
# NinjaOne Variables:
#   $adminUsername      - Script variable: desired admin username
#   $password           - Script variable: desired admin password
#   $adminPasswordField - Script variable: name of the org-level custom field
#                         containing the admin password (defaults to "adminPassword")
#
# Usage (interactive):
#   sudo ./Create Admin User.sh
#   (will prompt for username and password if not set via environment)

# When called, the process ends.
# Args:
# 	$1: The exit message (print to stderr)
# 	$2: The exit code (default is 1)
die() {
    local _ret="${2:-1}"
    echo "$1" >&2
    exit "${_ret}"
}

getHiddenUserUid() {
    local __UniqueIDs
    __UniqueIDs=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -ugr)

    local __NewUID
    for __NewUID in $__UniqueIDs; do
        if [[ $__NewUID -lt 499 ]]; then
            break
        fi
    done

    echo $((__NewUID + 1))
}

# --- Determine admin username ---
# Priority: $adminUsername env var > interactive prompt > default "admin"
_arg_user="${adminUsername:-}"
if [[ -z "$_arg_user" ]]; then
    # Not running from RMM — prompt if interactive
    if [[ -t 0 ]]; then
        read -rp "Enter admin username (default: admin): " _arg_user
    fi
    _arg_user="${_arg_user:-admin}"
fi

# --- Determine admin password ---
# Priority: $password env var > NinjaOne custom field > interactive prompt
_arg_pass="${password:-}"

if [[ -z "$_arg_pass" ]]; then
    # Try NinjaOne custom field (field name is configurable)
    _customFieldName="${adminPasswordField:-adminPassword}"
    if [[ -x "/Applications/NinjaRMMAgent/programdata/ninjarmm-cli" ]]; then
        _arg_pass=$(/Applications/NinjaRMMAgent/programdata/ninjarmm-cli get "$_customFieldName" 2>/dev/null)
    fi
fi

if [[ -z "$_arg_pass" ]]; then
    # Not running from RMM or field was empty — prompt if interactive
    if [[ -t 0 ]]; then
        read -rsp "Enter password for '$_arg_user': " _arg_pass
        echo
    fi
fi

# --- Validate inputs ---
if [[ -z "${_arg_user}" ]]; then
    die "FATAL ERROR: Username is required. Set \$adminUsername or run interactively." 1
fi

if [[ -z "${_arg_pass}" ]]; then
    die "FATAL ERROR: Password is required. Set \$password, configure the NinjaOne custom field, or run interactively." 1
fi

echo "Creating admin user: $_arg_user"

# Check for presence of user account and delete it if it exists before creating the new account
if id "$_arg_user" &>/dev/null; then
    echo "Deleting existing user account: $_arg_user"
    dscl . -delete /Users/"$_arg_user"
    rm -rf /Users/"$_arg_user"
fi

# Create the new user account
UniqueID=$(getHiddenUserUid)
if [ "$(id -u)" -eq 0 ]; then
    if dscl . -create /Users/"$_arg_user"; then
        dscl . -create /Users/"$_arg_user" UserShell /bin/bash
        dscl . -create /Users/"$_arg_user" RealName "$_arg_user"
        dscl . -create /Users/"$_arg_user" UniqueID "$UniqueID"
        dscl . -create /Users/"$_arg_user" PrimaryGroupID 20
        dscl . -create /Users/"$_arg_user" IsHidden 1 # Hide the user from the login window
        dscl . -create /Users/"$_arg_user" NFSHomeDirectory /Users/"$_arg_user"
        dscl . -passwd /Users/"$_arg_user" "$_arg_pass"
        dscl . -append /Users/"$_arg_user" AuthenticationAuthority ";DisabledTags;SecureToken" # Use secure token, bootstrap token, and volume ownership in deployments
        dscl . -append /Groups/admin GroupMembership "$_arg_user"
        dscl . -append /Groups/_lpadmin GroupMembership "$_arg_user"
        dscl . -append /Groups/_appserveradm GroupMembership "$_arg_user"
        dscl . -append /Groups/_appserverusr GroupMembership "$_arg_user"
        createhomedir -c 2>&1 | grep -v "shell-init"
        sudo chflags hidden /Users/"$_arg_user" # Hide the user's home folder
        echo "User $_arg_user created successfully."
    else
        echo "ERROR: Failed to create user."
        exit 1
    fi
else
    echo "Only root may add a user to the system."
    exit 2
fi

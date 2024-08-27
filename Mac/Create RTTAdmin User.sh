#!/usr/bin/env bash
#
# Description: Started from "New Admin User Mac" supplied by NinjaONE.
# Added logic to pull rttadmin password from Global Custom Field

# # When called, the process ends.
# Args:
# 	$1: The exit message (print to stderr)
# 	$2: The exit code (default is 1)
# if env var _PRINT_HELP is set to 'yes', the usage is print to stderr (prior to $1)
# Example:
# 	test -f "$_arg_infile" || _PRINT_HELP=yes die "Can't continue, have to supply file as an argument, got '$_arg_infile'" 4
die() {
    local _ret="${2:-1}"
    test "${_PRINT_HELP:-no}" = yes && print_help >&2
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

# Set the default values of the arguments
_arg_user="rttadmin" # set default username to rttadmin if not provided by Parameters field

# if environment variable $password is not set at runtime or is empty, set $_arg_pass to the org-level Custom Field value of 'roundtableAdmin'
roundtableAdmin=$(/Applications/NinjaRMMAgent/programdata/ninjarmm-cli get roundtableAdmin) # Supplied by org-level Custom Field
_arg_pass=${password:-$roundtableAdmin} # set default password to the Custom Field 'roundtableAdmin' value if not provided by Parameters field

if [[ -z "${_arg_user}" ]]; then
    die "FATAL ERROR: User Name is required. '$_arg_user'" 1
fi

if [[ -z "${_arg_pass}" ]]; then
    die "FATAL ERROR: Password is required. '$_arg_pass'" 1
fi

# Check for presence of user account defined by $_arg_user and delete it if it exists before creating the new account
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
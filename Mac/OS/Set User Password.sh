#!/bin/bash

# Change user password [MAC]
# Reset a user password; avoid special characters and spaces
# This script works with Ninja RMM environment variables

echo "Reset macOS Account Password"
echo "=========================================="

# Get username and password from Ninja RMM environment variables
# Note: Ninja uses lowercase variable names (usrun, usrpwd, reboot)
usrUN="${usrun}"
usrPWD="${usrpwd}"
REBOOT="${reboot}"

# Validate that both variables are set
if [[ -z "${usrUN}" ]] || [[ -z "${usrPWD}" ]]; then
    echo "Error: Username or password not provided."
    echo "Please set 'usrun' (username) and 'usrpwd' (password) parameters in Ninja RMM."
    exit 1
fi

echo "- Resetting password for user: $usrUN"
echo "--------------------------------"

# Check if the user exists
if ! id "$usrUN" &>/dev/null; then
    echo "Error: User $usrUN does not exist."
    exit 1
fi

echo "- User $usrUN exists, proceeding with password change."

# Capture the full output including stderr
OUTPUT=$(sysadminctl -resetPasswordFor "$usrUN" -newPassword "$usrPWD" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

# Check for secure token error
if echo "$OUTPUT" | grep -q "secure token"; then
    echo ""
    echo "ERROR: Secure Token is required to change this password."
    echo "This Mac has FileVault or secure boot enabled."
    echo ""
    echo "To reset the password, you need to:"
    echo "  1. Have physical access to the Mac"
    echo "  2. Boot into Recovery Mode (Command+R at startup)"
    echo "  3. Use Terminal in Recovery Mode to reset the password"
    echo "  OR"
    echo "  4. Use an admin account that has a secure token to change it"
    exit 1
fi

# Check exit code
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "- User account password changed successfully!"
    
    # Check if automatic reboot is requested (checkbox returns "true" or "false")
    if [[ "${REBOOT}" == "true" ]]; then
        echo "- Automatic reboot requested. System will reboot in 10 seconds..."
        echo "  This will lock out the user immediately."
        shutdown -r +10 "Password has been reset. System rebooting for security purposes." &
        exit 0
    else
        echo "  It may be wise to reboot the device before signing into it."
    fi
else
    echo "Error: Failed to change the password for user: $usrUN"
    exit 1
fi

echo "- Password change completed for user: $usrUN"
exit 0

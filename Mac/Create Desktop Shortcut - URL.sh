#!/bin/bash
# Search for every users' Desktop folder and create a .url file with a custom name and url identified in variables

# If urltitle or url are not supplied, exit with error
if [ -z "$urltitle" ] || [ -z "$url" ]; then
    echo "url Title or url address not supplied! $urltitle $url"
    exit 1
fi

# Search for every user in the /Users directory
for user in /Users/*; do
    # Check if the user has a Desktop folder
    if [ -d "$user/Desktop" ]; then
        # Create a .url file with the url in the Desktop folder
        url_file="$user/Desktop/$urltitle.url"
        echo "[InternetShortcut]" > "$url_file"
        echo "URL=$url" >> "$url_file"
        # Change the owner of the file to the user
        chown $(basename $user) "$url_file"    
        # Report the creation of the .url file
        echo "Created $url_file"
    fi
done

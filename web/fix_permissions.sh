#!/bin/bash

# Fix permissions for Apache to access SciMiner
# Choose ONE of the methods below

echo "Choose a method to fix Apache access:"
echo "1. Make home directory accessible by others (less secure)"
echo "2. Add www-data to sciminer group (recommended)"
echo "3. Move web files to /var/www/ (most secure)"

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo "Method 1: Making home directory accessible..."
        chmod 755 /home/sciminer
        echo "Done! Home directory is now accessible by Apache."
        ;;
    2)
        echo "Method 2: Adding www-data to sciminer group..."
        sudo usermod -a -G sciminer www-data
        chmod 750 /home/sciminer
        echo "Done! www-data user added to sciminer group."
        echo "You may need to restart Apache for changes to take effect."
        ;;
    3)
        echo "Method 3: Moving files to /var/www/sciminer..."
        sudo mkdir -p /var/www/sciminer
        sudo cp -r /home/sciminer/web/html/* /var/www/sciminer/
        sudo chown -R www-data:www-data /var/www/sciminer
        echo "Files moved to /var/www/sciminer"
        echo "You'll need to update Apache config to use DocumentRoot /var/www/sciminer"
        ;;
    *)
        echo "Invalid choice!"
        exit 1
        ;;
esac

# Also ensure CGI scripts have correct permissions
echo "Fixing CGI script permissions..."
find /home/sciminer/web/html -name "*.cgi" -exec chmod 755 {} \;
find /home/sciminer/web/html -name "*.pl" -exec chmod 755 {} \;
echo "Done!"
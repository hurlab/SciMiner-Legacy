#!/bin/bash

# Quick fix for Apache permissions - just run this!
echo "Fixing Apache permissions..."

# Allow Apache to access home directory
chmod 755 /home/sciminer

# Make sure web files are accessible
chmod -R 755 /home/sciminer/web

# Make CGI scripts executable
find /home/sciminer/web/html -name "*.cgi" -exec chmod +x {} \;
find /home/sciminer/web/html -name "*.pl" -exec chmod +x {} \;

echo "Permissions fixed!"
echo "Now restart Apache:"
echo "  sudo systemctl restart apache2"
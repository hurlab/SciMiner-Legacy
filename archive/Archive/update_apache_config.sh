#!/bin/bash
# Script to update Apache configuration for system Perl

echo "Updating Apache configuration for system Perl deployment..."

# Backup original config
sudo cp /etc/apache2/sites-available/sciminer.conf /etc/apache2/sites-available/sciminer.conf.backup

# Update the configuration to remove conda-specific paths
sudo sed -i 's|SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules|SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules|g' /etc/apache2/sites-available/sciminer.conf

# Restart Apache
sudo systemctl restart apache2

echo "Apache configuration updated and server restarted!"
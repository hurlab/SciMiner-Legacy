#!/bin/bash

# Script to update Apache configuration for Conda environment
# Run with: bash update_apache_conda.sh

# Configuration
CONDA_ENV="sciminer"
CONDA_PREFIX="/home/sciminer/miniconda3/envs/$CONDA_ENV"

echo "Updating Apache configuration for Conda environment..."
echo "Conda Environment: $CONDA_ENV"
echo "Conda Prefix: $CONDA_PREFIX"

# Create Apache configuration
sudo tee /etc/apache2/sites-available/sciminer.conf > /dev/null <<EOF
<VirtualHost *:8888>
    ServerName localhost
    ServerAdmin admin@localhost

    # Document root for SciMiner
    DocumentRoot /home/sciminer/web/html

    # Use Conda Perl environment
    PerlSwitches -I$CONDA_PREFIX/lib/site_perl/5.40.2
    SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules:$CONDA_PREFIX/lib/site_perl/5.40.2
    SetEnv PATH $CONDA_PREFIX/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    SetEnv PERL_BADLANG 0

    # Directory configuration
    <Directory /home/sciminer/web/html>
        Options Indexes FollowSymLinks ExecCGI
        AllowOverride None
        Require all granted
    </Directory>

    # Enable CGI for .cgi files in SciMiner directory
    <Directory "/home/sciminer/web/html/SciMiner">
        Options +ExecCGI
        AddHandler cgi-script .cgi .pl
        Require all granted
    </Directory>

    # DirectoryIndex
    DirectoryIndex index.html index.htm

    # Error and access logs
    ErrorLog \${APACHE_LOG_DIR}/sciminer_error.log
    CustomLog \${APACHE_LOG_DIR}/sciminer_access.log combined
</VirtualHost>
EOF

# Update ports
echo "Listen 8888" | sudo tee /etc/apache2/ports.conf > /dev/null

# Enable site
sudo a2dissite 000-default 2>/dev/null || true
sudo a2ensite sciminer

# Enable modules
sudo a2enmod cgi cgid 2>/dev/null || true

# Restart Apache
echo "Restarting Apache..."
sudo systemctl restart apache2

echo "Apache configuration updated!"
echo "Test at: http://localhost:8888/SciMiner/test_environment.cgi"
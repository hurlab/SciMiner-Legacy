#!/bin/bash

# Setup script for Apache HTTP Server with SciMiner
# Run with: sudo bash setup_apache.sh

echo "Setting up Apache HTTP Server for SciMiner..."

# Step 1: Enable required Apache modules
echo "Enabling Apache modules..."
a2enmod cgi
a2enmod alias
a2enmod env
a2enmod reqtimeout

# Step 2: Create site configuration
echo "Creating Apache site configuration..."
cat > /etc/apache2/sites-available/sciminer.conf << 'EOF'
<VirtualHost *:8888>
    ServerName localhost
    ServerAdmin sciminer@localhost

    # Document root for SciMiner
    DocumentRoot /home/sciminer/web/html

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

    # DirectoryIndex - serve index.html by default
    DirectoryIndex index.html index.htm

    # Error and access logs
    ErrorLog ${APACHE_LOG_DIR}/sciminer_error.log
    CustomLog ${APACHE_LOG_DIR}/sciminer_access.log combined

    # Set environment variables for SciMiner
    SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules

    # Increase timeout for long-running scripts
    <IfModule mod_reqtimeout.c>
        RequestReadTimeout header=20-40,MinRate=500 body=10,MinRate=500
    </IfModule>
</VirtualHost>
EOF

# Step 3: Configure ports
echo "Configuring Apache to listen on port 8888..."
cat > /etc/apache2/ports.conf << 'EOF'
Listen 8888
<IfModule ssl_module>
    Listen 8443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 8443
</IfModule>
EOF

# Step 4: Disable default site and enable SciMiner site
echo "Disabling default site and enabling SciMiner..."
a2dissite 000-default
a2ensite sciminer

# Step 5: Set proper permissions
echo "Setting permissions for SciMiner directory..."
chmod -R 755 /home/sciminer/web/html
find /home/sciminer/web/html/SciMiner -name "*.cgi" -exec chmod +x {} \;
find /home/sciminer/web/html/SciMiner -name "*.pl" -exec chmod +x {} \;

# Step 6: Test Apache configuration
echo "Testing Apache configuration..."
apache2ctl configtest

# Step 7: Restart Apache
echo "Restarting Apache..."
systemctl restart apache2
systemctl status apache2

echo ""
echo "Apache setup complete!"
echo "SciMiner should be accessible at: http://localhost:8888/SciMiner/"
echo ""
echo "Check logs with:"
echo "  tail -f /var/log/apache2/sciminer_access.log"
echo "  tail -f /var/log/apache2/sciminer_error.log"
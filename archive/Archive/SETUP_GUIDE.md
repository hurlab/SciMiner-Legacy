# SciMiner Setup Guide

This guide provides step-by-step instructions for setting up SciMiner on Ubuntu/Debian Linux systems.

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Prerequisites](#prerequisites)
3. [Database Setup](#database-setup)
4. [Apache Web Server Configuration](#apache-web-server-configuration)
5. [Perl Module Dependencies](#perl-module-dependencies)
6. [File Permissions](#file-permissions)
7. [Testing the Installation](#testing-the-installation)
8. [Troubleshooting](#troubleshooting)
9. [Security Considerations](#security-considerations)

## System Requirements

- **OS**: Ubuntu 20.04+ / Debian 10+
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 10GB free space
- **Database**: MySQL 5.7+ or MariaDB 10.3+

## Prerequisites

### 1. Update System Packages
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### 2. Install Required Packages
```bash
# Install Apache web server
sudo apt-get install -y apache2

# Install MySQL/MariaDB database
sudo apt-get install -y mysql-server
# OR for MariaDB
# sudo apt-get install -y mariadb-server

# Install Perl and essential modules
sudo apt-get install -y perl perl-base

# Install development tools (required for some Perl modules)
sudo apt-get install -y build-essential
```

### 3. Install Additional System Tools
```bash
# Install cpanminus for Perl module management
sudo apt-get install -y cpanminus

# Install version control
sudo apt-get install -y git

# Install text editors (optional)
sudo apt-get install -y vim nano
```

## Database Setup

### 1. Secure Database Installation
```bash
sudo mysql_secure_installation
```

### 2. Create SciMiner Database and User
```bash
# Log in to MySQL as root
sudo mysql -u root -p

# Run these SQL commands in MySQL shell:
CREATE DATABASE sciminer CHARACTER SET latin1 COLLATE latin1_swedish_ci;
CREATE USER 'sciminer'@'localhost' IDENTIFIED BY 'your_password_here';
GRANT ALL PRIVILEGES ON sciminer.* TO 'sciminer'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Import SciMiner Database Schema
```bash
# If you have the sciminer.sql dump file
mysql -u sciminer -p sciminer < /path/to/sciminer.sql

# Note: Replace /path/to/sciminer.sql with actual path
```

### 4. Verify Database Creation
```bash
mysql -u sciminer -p sciminer -e "SHOW TABLES;"
```

## Apache Web Server Configuration

### 1. Enable Required Apache Modules
```bash
sudo a2enmod cgi
sudo a2enmod alias
sudo a2enmod env
sudo a2enmod reqtimeout
sudo a2enmod cgid  # For threaded MPM
```

### 2. Create Apache Virtual Host Configuration
Create `/etc/apache2/sites-available/sciminer.conf`:

```apache
<VirtualHost *:8888>
    ServerName localhost
    ServerAdmin admin@yourdomain.com

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
```

### 3. Configure Apache Port
Edit `/etc/apache2/ports.conf`:
```apache
# Listen on port 8888 for SciMiner
Listen 8888

# Optional: Also listen on port 80
# Listen 80
```

### 4. Enable Site and Restart Apache
```bash
# Disable default site
sudo a2dissite 000-default

# Enable SciMiner site
sudo a2ensite sciminer

# Restart Apache
sudo systemctl restart apache2

# Check Apache status
sudo systemctl status apache2
```

## Perl Module Dependencies

### 1. Install System Perl Modules
```bash
# Database interface
sudo apt-get install -y libdbi-perl libdbd-mysql-perl

# Web framework modules
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl

# HTTP and networking
sudo apt-get install -y libwww-perl liblwp-protocol-https-perl

# Additional modules
sudo apt-get install -y libio-socket-ssl-perl libnet-ssleay-perl
sudo apt-get install -y libmailtools-perl libauthen-sasl-perl
```

### 2. Install CPAN Modules
```bash
# Install Text::NSP (for statistical analysis)
sudo cpanm Text::NSP

# Install session management
sudo cpanm CGI::Session

# Install statistical modules
sudo cpanm Statistics::ChisqIndep
sudo cpanm Statistics::Distributions

# Install additional required modules
sudo cpanm HTML::Parser
sudo cpanm XML::Simple
sudo cpanm JSON
sudo cpanm Date::Calc
sudo cpanm URI::Escape
sudo cpanm MIME::Base64
sudo cpanm Digest::MD5
sudo cpanm Text::Wrap
```

### 3. Alternative: Install All Dependencies with CPAN
```bash
# Create a list of required modules
cat > /tmp/sciminer_modules.txt << EOF
DBI
DBD::mysql
CGI
HTML::Template
LWP::UserAgent
Text::NSP
CGI::Session
Statistics::ChisqIndep
Statistics::Distributions
HTML::Parser
XML::Simple
JSON
Date::Calc
URI::Escape
MIME::Base64
Digest::MD5
Text::Wrap
IO::Socket::SSL
Net::SSLeay
Mail::Sendmail
Authen::SASL
EOF

# Install all modules
sudo cpanm < /tmp/sciminer_modules.txt
```

## File Permissions

### 1. Set Directory Permissions
```bash
# Make home directory accessible to Apache
chmod 755 /home/sciminer

# Set web directory permissions
chmod -R 755 /home/sciminer/web

# Make scripts executable
find /home/sciminer/web/html -name "*.cgi" -exec chmod +x {} \;
find /home/sciminer/web/html -name "*.pl" -exec chmod +x {} \;
```

### 2. Create Necessary Directories
```bash
# Create temporary directory for SciMiner
sudo mkdir -p /tmp/SciMiner
sudo chmod 777 /tmp/SciMiner

# Create log directory if needed
mkdir -p /home/sciminer/web/var/log
chmod 755 /home/sciminer/web/var/log
```

## Configure SciMiner

### 1. Edit Configuration File
Edit `/home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini`:

```ini
[SciMinerDB]
OS=linux
ANNOPath=/home/sciminer/ANNOTATION/
SciMinerPath=/home/sciminer/ANNOTATION/SciMinerDB/
SciMinerWebPath=/home/sciminer/web/html/SciMiner/
SciMinerWebTempPath=/tmp/SciMiner/
SciMinerServerURL=http://localhost:8888/
HTTPProxyServer=
ProcessFullTextHtml=TRUE
Perl=/usr/bin/perl
Institution=Your Institution Name
AdminEmail=admin@yourdomain.com
DB=sciminer
username=sciminer
password=your_database_password_here
WholePMID=19443143
SendMail=0
MaxDoc=1000
MaxNewDoc=500
```

### 2. Update Database Password in Perl Scripts
Some Perl scripts might need the database password updated. Search for connection strings in:
- `/home/sciminer/ANNOTATION/SciMinerDB/Modules/Annotation/basicIO.pm`
- Other `.pm` files

## Testing the Installation

### 1. Create Test CGI Script
Create `/home/sciminer/web/html/SciMiner/test_cgi.cgi`:

```perl
#!/usr/bin/perl

print "Content-Type: text/plain\n\n";
print "SciMiner CGI Test\n";
print "=================\n\n";

print "Perl Version: $]\n";
print "Current Directory: " . `pwd` . "\n";

# Test database connection
use DBI;
my $dsn = "DBI:mysql:database=sciminer;host=localhost";
my $user = "sciminer";
my $pass = "your_password";  # Replace with actual password

eval {
    my $dbh = DBI->connect($dsn, $user, $pass);
    if ($dbh) {
        print "SUCCESS: Database connection established\n";
        $dbh->disconnect();
    } else {
        print "ERROR: Cannot connect to database\n";
    }
};
if ($@) {
    print "ERROR: $@\n";
}

# Test module loading
BEGIN {
    push (@INC, "/home/sciminer/ANNOTATION/SciMinerDB/Modules/");
}

eval {
    require Annotation::basicIO;
    print "SUCCESS: Annotation::basicIO loaded\n";
};
if ($@) {
    print "WARNING: Annotation::basicIO not loaded: $@\n";
}

print "\nEnvironment Variables:\n";
print "Server Name: $ENV{SERVER_NAME}\n";
print "Server Port: $ENV{SERVER_PORT}\n";
```

Make it executable:
```bash
chmod +x /home/sciminer/web/html/SciMiner/test_cgi.cgi
```

### 2. Test Web Access
Open in browser or use curl:
```bash
# Test main page
curl -I http://localhost:8888/SciMiner/

# Test CGI script
curl http://localhost:8888/SciMiner/test_cgi.cgi
```

### 3. Check Apache Logs
```bash
# Check error log
sudo tail -f /var/log/apache2/sciminer_error.log

# Check access log
sudo tail -f /var/log/apache2/sciminer_access.log
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Forbidden (403) Error
```bash
# Check permissions
ls -la /home/sciminer/
ls -la /home/sciminer/web/

# Fix permissions
chmod 755 /home/sciminer
chmod -R 755 /home/sciminer/web
```

#### 2. Internal Server Error (500)
```bash
# Check Apache error log
sudo tail -20 /var/log/apache2/sciminer_error.log

# Check script syntax
cd /home/sciminer/web/html/SciMiner
perl -c script_name.cgi

# Check missing Perl modules
perl script_name.cgi 2>&1 | grep "Can't locate"
```

#### 3. Database Connection Failed
```bash
# Test MySQL connection
mysql -u sciminer -p sciminer

# Check if MySQL is running
sudo systemctl status mysql
```

#### 4. Modules Not Found
```bash
# Install missing module
sudo cpanm Module::Name

# Or search for system package
apt-cache search perl-module-name
```

### Debug Mode

Enable CGI debugging by adding to your scripts:
```perl
use CGI::Debug;
```

Or check errors in browser with:
```bash
# Add this to Apache config for debugging
PerlModule CGI::Carp
```

## Security Considerations

### 1. File Permissions
- Keep home directory at 755, not 777
- Ensure sensitive files have restrictive permissions (600)
- Don't store passwords in world-readable files

### 2. Database Security
- Use strong database passwords
- Limit database user privileges
- Consider SSL for database connections

### 3. Apache Security
```bash
# Disable directory listing in production
# Change "Options Indexes" to "Options -Indexes"

# Add security headers (optional)
# Add to Apache config:
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
```

### 4. Firewall Configuration
```bash
# Allow Apache through firewall
sudo ufw allow 8888/tcp

# Or only allow from specific IPs
sudo ufw allow from 192.168.1.0/24 to any port 8888
```

## Performance Optimization

### 1. Apache Configuration
Edit `/etc/apache2/mods-enabled/mpm_prefork.conf`:
```apache
<IfModule mpm_prefork_module>
    StartServers 4
    MinSpareServers 4
    MaxSpareServers 8
    MaxRequestWorkers 80
    MaxConnectionsPerChild 1000
</IfModule>
```

### 2. MySQL Configuration
Edit `/etc/mysql/mysql.conf.d/mysqld.cnf`:
```ini
[mysqld]
# Memory settings
innodb_buffer_pool_size = 1G
key_buffer_size = 256M

# Connection settings
max_connections = 100
max_allowed_packet = 64M
```

## Maintenance

### 1. Log Rotation
Create `/etc/logrotate.d/sciminer`:
```
/var/log/apache2/sciminer_*.log {
    weekly
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    postrotate
        systemctl reload apache2
    endscript
}
```

### 2. Database Backup
```bash
#!/bin/bash
# Create backup script: /usr/local/bin/backup_sciminer.sh
DATE=$(date +%Y%m%d_%H%M%S)
mysqldump -u sciminer -p sciminer > /backup/sciminer_$DATE.sql
gzip /backup/sciminer_$DATE.sql
```

### 3. System Monitoring
```bash
# Monitor Apache processes
ps aux | grep apache2

# Monitor MySQL
mysqladmin status

# Check disk space
df -h
```

## Additional Resources

- [Apache Documentation](https://httpd.apache.org/docs/)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [Perl Documentation](https://perldoc.perl.org/)
- [CPAN Module Search](https://metacpan.org/)

## Support

For issues specific to SciMiner:
1. Check the error logs
2. Verify all dependencies are installed
3. Ensure file permissions are correct
4. Test with the provided test scripts

Remember: This is a legacy system from ~2008. Some components may require updates for modern systems.
# SciMiner Quick Reference Guide

## One-Line Installation
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/sciminer/main/install_sciminer.sh | bash
```

## Manual Setup Commands

### 1. Install Dependencies
```bash
sudo apt-get update
sudo apt-get install -y apache2 mysql-server perl build-essential cpanminus
sudo apt-get install -y libdbi-perl libdbd-mysql-perl libcgi-pm-perl libhtml-template-perl libwww-perl
```

### 2. Configure Apache
```bash
# Enable modules
sudo a2enmod cgi alias env reqtimeout

# Create virtual host at /etc/apache2/sites-available/sciminer.conf
# (See SETUP_GUIDE.md for full config)

# Enable site
sudo a2ensite sciminer
sudo a2dissite 000-default
sudo systemctl restart apache2
```

### 3. Setup Database
```bash
sudo mysql -e "CREATE DATABASE sciminer; CREATE USER 'sciminer'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON sciminer.* TO 'sciminer'@'localhost';"
mysql -u sciminer -p sciminer < sciminer.sql
```

### 4. Install Perl Modules
```bash
sudo cpanm Text::NSP CGI::Session Statistics::ChisqIndep
```

### 5. Fix Permissions
```bash
chmod 755 /home/sciminer
chmod -R 755 /home/sciminer/web
find /home/sciminer/web/html -name "*.cgi" -exec chmod +x {} \;
```

## Access URLs
- Main Page: http://localhost:8888/SciMiner/
- Test Script: http://localhost:8888/SciMiner/test_installation.cgi

## Important Files
- Config: `/home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini`
- Apache Config: `/etc/apache2/sites-available/sciminer.conf`
- Error Log: `/var/log/apache2/sciminer_error.log`

## Common Commands
```bash
# Restart Apache
sudo systemctl restart apache2

# Check MySQL status
sudo systemctl status mysql

# Install missing Perl module
sudo cpanm Module::Name

# View logs
sudo tail -f /var/log/apache2/sciminer_error.log
```

## Troubleshooting Quick Fix
```bash
# 403 Forbidden error
chmod 755 /home/sciminer

# 500 Internal Server Error
tail /var/log/apache2/sciminer_error.log

# Database connection error
mysql -u sciminer -p
```
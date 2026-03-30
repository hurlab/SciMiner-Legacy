# SciMiner Installation Guide - System Perl Deployment

This guide explains how to deploy SciMiner using system Perl and packages for better distribution and compatibility.

## Overview

This deployment approach:
- Uses system Perl (default Perl installation)
- Installs dependencies via system package manager (apt)
- Eliminates dependency on conda environment
- Simplifies distribution and deployment
- Works with standard Linux configurations

## System Requirements

- Ubuntu/Debian Linux (18.04 or later)
- Root/sudo access for package installation
- Apache2 web server
- MariaDB or MySQL database

## Quick Installation

### Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script with sudo
sudo ./deploy_sciminer.sh

# The script will:
# 1. Install all required packages
# 2. Configure the database
# 3. Setup Apache web server
# 4. Configure SciMiner
# 5. Verify the installation
```

### Option 2: Manual Installation

#### 1. Install Required Packages

**For Ubuntu 24.04 (Noble):**

```bash
# Quick installation (Ubuntu 24.04 compatible)
sudo ./QUICK_INSTALL_UBUNTU24.sh

# Or manually:
sudo apt-get update
sudo apt-get install -y \
    build-essential gcc make \
    libdbi-perl \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    libcgi-pm-perl \
    libcgi-application-perl \
    libyaml-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libhtml-template-perl \
    libspreadsheet-writeexcel-perl \
    libjson-perl \
    liburi-perl \
    libwww-perl \
    libhttp-message-perl \
    libcgi-session-perl \
    apache2 \
    mariadb-server

# Install Text::NSP via CPAN (not available in Ubuntu 24.04)
sudo apt-get install -y cpanminus
sudo cpanm --notest Text::NSP

# For YAML::XS, if system package fails:
sudo cpanm --notest YAML::XS
```

**For Ubuntu 22.04 and earlier:**
You can use the older package names including `libtext-nsp-perl`.

#### 2. Setup Database

```bash
# Start and enable MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Create database and user
sudo mysql -e "CREATE DATABASE sciminer;"
sudo mysql -e "CREATE USER 'sciminer'@'localhost' IDENTIFIED BY '124356!@';"
sudo mysql -e "GRANT ALL PRIVILEGES ON sciminer.* TO 'sciminer'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Import database schema (if available)
mysql -u sciminer -p sciminer < sciminer.sql
```

#### 3. Configure Apache

```bash
# Create Apache configuration
sudo cat > /etc/apache2/sites-available/sciminer.conf << 'EOF'
<VirtualHost *:8888>
    ServerName localhost
    ServerAdmin sciminer@localhost

    DocumentRoot /home/sciminer/web/html

    <Directory /home/sciminer/web/html>
        Options Indexes FollowSymLinks ExecCGI
        AllowOverride None
        Require all granted
    </Directory>

    <Directory "/home/sciminer/web/html/SciMiner">
        Options +ExecCGI
        AddHandler cgi-script .cgi .pl
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/sciminer_error.log
    CustomLog ${APACHE_LOG_DIR}/sciminer_access.log combined

    SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules
</VirtualHost>
EOF

# Enable site and modules
sudo a2ensite sciminer.conf
sudo a2enmod cgi
sudo a2enmod rewrite
echo "Listen 8888" | sudo tee -a /etc/apache2/ports.conf

# Set permissions
sudo chown -R sciminer:sciminer /home/sciminer/web
find /home/sciminer/web/html -name "*.cgi" -exec chmod +x {} \;

# Restart Apache
sudo systemctl restart apache2
```

#### 4. Update Configuration

Edit `/home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini`:

```ini
SciMinerServerURL=http://localhost:8888/
DB=sciminer
username=sciminer
password=124356!@
```

## Verification

### Check Perl Modules

```bash
# Run the module check script
./check_system_perl_modules.pl

# Expected output should show:
# - DBI: Installed
# - DBD::mysql: Installed
# - CGI: Installed
# - HTML::Template: Installed
```

### Test Web Interface

```bash
# Test if the web interface is accessible
curl http://localhost:8888/SciMiner/

# Or open in a web browser:
# http://localhost:8888/SciMiner/
```

### Debugging

If CGI scripts return 500 errors:

1. Check Apache error log:
```bash
sudo tail -f /var/log/apache2/sciminer_error.log
```

2. Test CGI script from command line:
```bash
cd /home/sciminer/web/html/SciMiner
./sciminer.cgi
```

## Important Files

| File | Purpose |
|------|---------|
| `requirements.ubuntu` | List of system package dependencies |
| `deploy_sciminer.sh` | Automated deployment script |
| `check_system_perl_modules.pl` | Verify Perl module installation |
| `install_system_perl_packages.sh` | Install missing Perl packages |
| `/etc/apache2/sites-available/sciminer.conf` | Apache configuration |
| `/home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini` | Main SciMiner configuration |

## Security Considerations

1. **Change Default Passwords**: Update the database password in production
2. **Firewall Configuration**: Configure firewall to allow port 8888
3. **File Permissions**: Ensure proper permissions on sensitive files
4. **Apache Security**: Review and harden Apache configuration

## Migration from Conda

If migrating from a conda-based installation:

1. All CGI scripts have been updated to use `#!/usr/bin/perl`
2. System Perl packages replace conda packages
3. Apache configuration updated for system paths
4. Database configuration remains the same

## Troubleshooting

### Common Issues

1. **Module Not Found**
   - Install via system packages: `sudo apt-get install lib<module>-perl`
   - Check with: `/usr/bin/perl -M<Module> -le 'print "$Module version: $<Module>::VERSION"'`

2. **CGI Script Permission Denied**
   - Check permissions: `ls -la /home/sciminer/web/html/SciMiner/*.cgi`
   - Fix permissions: `chmod +x /home/sciminer/web/html/SciMiner/*.cgi`

3. **Database Connection Failed**
   - Verify MariaDB/MySQL is running: `sudo systemctl status mariadb`
   - Check credentials in annotationENV.ini
   - Test connection: `mysql -u sciminer -p sciminer`

4. **Apache 500 Error**
   - Check error log: `sudo tail /var/log/apache2/sciminer_error.log`
   - Usually caused by missing Perl modules

### Getting Help

- Check logs: `/var/log/apache2/sciminer_error.log`
- Run module check script: `./check_system_perl_modules.pl`
- Review configuration: `annotationENV.ini`

## Maintenance

### Updates

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade

# Check SciMiner status
curl http://localhost:8888/SciMiner/
```

### Backup

```bash
# Backup database
mysqldump -u sciminer -p sciminer > sciminer_backup_$(date +%Y%m%d).sql

# Backup configuration
tar -czf sciminer_config_backup_$(date +%Y%m%d).tar.gz \
    /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini \
    /etc/apache2/sites-available/sciminer.conf
```

## Next Steps

After successful installation:

1. Review the [Refactoring Plan](REFACTORING_PLAN.md) for modernization
2. Check [Production Security Checklist](PRODUCTION_SECURITY_CHECKLIST.md)
3. Test all SciMiner features
4. Consider setting up SSL/TLS for production use

---

## Architecture Notes

This system-based deployment provides:

- **Portability**: Works on any standard Ubuntu/Debian system
- **Maintainability**: Uses system package management
- **Security**: Follows standard Linux security practices
- **Scalability**: Easy to deploy multiple instances
- **Compatibility**: Works with existing infrastructure

The conda environment is no longer needed for production deployment, making distribution and maintenance much simpler.
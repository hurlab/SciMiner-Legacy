# Complete SciMiner Installation Guide - Ubuntu 24.04

## Overview

This guide provides a single-command installation for SciMiner using system Perl and packages on Ubuntu 24.04. This approach eliminates conda dependencies and provides a standard, maintainable deployment.

## Quick Installation

### Single Command Installation

Run this single command to install everything:

```bash
# As root or with sudo
sudo bash /home/sciminer/INSTALL_SCIMINER_COMPLETE.sh
```

This script will:
1. Install all system dependencies
2. Install required Perl modules via apt and CPAN
3. Fix known issues (Boulder::Medline syntax errors)
4. Configure Apache web server
5. Setup MariaDB database
6. Configure SciMiner
7. Run verification tests

## What Gets Installed

### System Packages
- Build tools (gcc, make, etc.)
- Apache2 web server
- MariaDB database
- Development headers for compilation

### Perl Modules (System)
- DBI, DBD::MySQL, DBD::SQLite
- CGI, CGI::Session, CGI::Application
- YAML, YAML::XS
- XML::LibXML, XML::Parser
- JSON, JSON::XS
- HTML::Template
- And more...

### Perl Modules (CPAN)
- Text::NSP
- Boulder::Medline
- Any modules not available in Ubuntu 24.04

## Configuration

### Default Settings
- **Web Port**: 8888
- **Database Name**: sciminer
- **Database User**: sciminer
- **Database Password**: 124356!@

### Customizing Installation

You can customize these settings before running:

```bash
export SCIMINER_HOME=/path/to/sciminer
export WEB_PORT=8080
export DB_NAME=my_sciminer
export DB_USER=myuser
export DB_PASS=mypassword

sudo bash /home/sciminer/INSTALL_SCIMINER_COMPLETE.sh
```

## Verification

### Automatic Verification
The installation script automatically runs the test script at the end to verify all modules are installed correctly.

### Manual Verification

```bash
# Check Perl modules
/home/sciminer/check_system_perl_modules.pl

# Test web interface
curl http://localhost:8888/SciMiner/

# Check Apache logs
sudo tail -f /var/log/apache2/sciminer_error.log
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   # Ensure running with proper privileges
   sudo bash INSTALL_SCIMINER_COMPLETE.sh
   ```

2. **Module Installation Fails**
   ```bash
   # Check module status
   /home/sciminer/check_system_perl_modules.pl

   # Install missing module manually
   sudo cpanm Module::Name
   ```

3. **Web Server Not Responding**
   ```bash
   # Check Apache status
   sudo systemctl status apache2

   # Check if port is listening
   sudo netstat -tulpn | grep :8888

   # Check error logs
   sudo tail /var/log/apache2/sciminer_error.log
   ```

4. **Database Connection Issues**
   ```bash
   # Check MariaDB status
   sudo systemctl status mariadb

   # Test database connection
   mysql -u sciminer -p sciminer
   ```

### Fixing Issues After Installation

If you need to reinstall or fix specific components:

```bash
# Reinstall Perl modules only
sudo apt-get install --reinstall libdbi-perl libdbd-mysql-perl

# Fix Boulder::Medline
/home/sciminer/medline_fix_complete.sh

# Reconfigure Apache
sudo systemctl reload apache2
```

## Security Considerations

For production deployment:

1. **Change Default Passwords**
   ```bash
   mysql -u root -p
   ALTER USER 'sciminer'@'localhost' IDENTIFIED BY 'new_secure_password';
   FLUSH PRIVILEGES;
   ```

2. **Configure Firewall**
   ```bash
   sudo ufw allow 8888/tcp
   sudo ufw enable
   ```

3. **Review File Permissions**
   ```bash
   # Check sensitive files
   ls -la /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini
   chmod 600 /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini
   ```

## Maintenance

### Updates

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade

# Update CPAN modules
sudo cpan-outdated -p | sudo xargs cpanm
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

### Logs

- **Apache Access Log**: `/var/log/apache2/sciminer_access.log`
- **Apache Error Log**: `/var/log/apache2/sciminer_error.log`
- **MariaDB Log**: `/var/log/mysql/error.log`

## Migration from Conda

If migrating from conda-based installation:

1. All CGI scripts have been updated to use system Perl (`#!/usr/bin/perl`)
2. Database remains the same (MariaDB)
3. Configuration file (`annotationENV.ini`) is preserved
4. No data migration needed

## Uninstallation

To remove SciMiner:

```bash
# Stop services
sudo systemctl stop apache2 mariadb

# Remove Apache configuration
sudo a2dissite sciminer.conf
sudo rm /etc/apache2/sites-available/sciminer.conf
sudo systemctl reload apache2

# Remove database (CAUTION: This deletes all data!)
mysql -u root -p -e "DROP DATABASE sciminer;"
mysql -u root -p -e "DROP USER 'sciminer'@'localhost';"

# Remove Perl modules (optional)
# Note: This may affect other applications
```

## File Locations

| Component | Location |
|-----------|----------|
| Web Root | `/home/sciminer/web/html` |
| Apache Config | `/etc/apache2/sites-available/sciminer.conf` |
| Perl Modules | `/usr/lib/x86_64-linux-gnu/perl5/5.38/` (system) |
| CPAN Modules | `/usr/local/share/perl/5.38.2/` |
| Database Files | `/var/lib/mysql/sciminer/` |
| Logs | `/var/log/apache2/` |

## Next Steps

After successful installation:

1. **Test SciMiner functionality**
   - Access web interface at http://localhost:8888/SciMiner/
   - Try a sample query
   - Verify all features work

2. **Customize for your needs**
   - Edit `annotationENV.ini` for specific settings
   - Add custom dictionaries
   - Configure custom workflows

3. **Review documentation**
   - Read SciMiner user manual
   - Check customization options
   - Review API documentation (if available)

## Support

For issues:
1. Check Apache error logs
2. Run verification script
3. Review this guide
4. Check SciMiner documentation

---

**Installation Script**: `INSTALL_SCIMINER_COMPLETE.sh`
**Test Script**: `check_system_perl_modules.pl`
**Documentation**: This file and `PERL_MODULE_LOCATIONS.md`
# SciMiner Integrated Installation Guide

## Quick Start

```bash
# 1. Switch to sciminer user
sudo su - sciminer

# 2. Run the installation
bash SETUP_INFRASTRUCTURE_FINAL.sh

# 3. Test the installation
curl http://localhost:8888/SciMiner/
```

**Important:**
- Run as 'sciminer' user, NOT as root
- The script will prompt for sudo password when needed
- All files will be owned by sciminer user
- Single unified script handles Apache2, MariaDB, database config, and Perl modules

## Overview
The `SETUP_INFRASTRUCTURE_FINAL.sh` script includes all components needed for a complete SciMiner installation in a single, unified process. It migrates from conda-based Perl to system Perl and sets up the entire infrastructure.

## Project Structure

### Essential Files
- **SETUP_INFRASTRUCTURE_FINAL.sh** - Main unified installation script
- **CONFIGURE_DATABASE.sh** - Database configuration script (standalone)
- **INSTALL_PERL_MODULES.sh** - Perl modules installation (standalone)
- **README.md** - Project overview
- **CLAUDE.md** - Architecture documentation for developers
- **REFACTORING_PLAN.md** - Modernization roadmap
- **INTEGRATED_INSTALLATION_GUIDE.md** - This installation guide

### Archive Folder
Contains all development scripts, intermediate versions, and progress documentation preserved for reference.

## Installation Stages

### Stage 1: Prerequisites Check
- Verifies running as sciminer user
- Checks sudo access
- Professional ASCII art introduction

### Stage 2: Apache Web Server Setup
- Checks for existing Apache2 installation
- Installs or reinstalls as needed
- Ensures Apache2 is running and enabled

### Stage 3: Apache Configuration for SciMiner
- Configures virtual host for port 8888
- Enables CGI execution for Perl scripts
- Sets up proper directory permissions
- Configures environment variables for SciMiner

### Stage 4: MariaDB Database Setup
- Installs or keeps existing MariaDB
- Ensures database service is running
- Handles both fresh and existing installations

### Stage 5: Database Status Check
- Transparent credential disclosure:
  - Database: sciminer
  - Username: sciminer
  - Password: 124356!@
- Checks database connection with default credentials
- Reports database status clearly

### Stage 6: Database Configuration
- Prompts for configuration if database is not set up
- Offers reconfiguration option if already configured
- Smart credential logic:
  1. Tries default sciminer credentials first
  2. Only prompts for admin credentials if needed
  3. Handles privilege-aware operations

### Stage 7: Perl Modules Installation
- Installs all required Perl modules for system Perl
- **Sub-stages**:
  - 7.1: Build tools and development headers
  - 7.2: System Perl packages from Ubuntu repositories
  - 7.3: CPAN modules (via cpanminus)
  - 7.4: Fix known issues (Boulder::Medline syntax)
  - 7.5: Update CGI scripts to use system Perl
- Accurate status reporting for each package
- Marks completion status for final report
- Includes CGI::Debug module for development debugging

### Stage 8: Final Configuration
- Sets proper file permissions
- Creates test HTML page
- Provides comprehensive status summary
- Tracks actual installation status

## Key Features

### 1. Single Script Installation
**As sciminer user (recommended):**
```bash
su - sciminer
bash SETUP_INFRASTRUCTURE_FINAL.sh
```

**Note:** The script will verify you're running as the correct user and check for sudo access.

### 2. Smart Credential Handling
- Default sciminer credentials used when possible
- Minimal credential prompts
- Clear disclosure of what's being used

### 3. Flexible and Non-Destructive
- Respects existing installations
- Options to keep or reinstall components
- User choice at each critical decision point

### 4. Comprehensive Status Reporting
- Clear status at each stage
- Final summary with all components
- Next steps clearly outlined

## Usage Examples

### Fresh Installation (Recommended)
```bash
sudo su - sciminer
bash SETUP_INFRASTRUCTURE_FINAL.sh
```
The script will:
- Check prerequisites and introduce SciMiner
- Install Apache2 and MariaDB if needed
- Configure database with smart credential handling
- Install all Perl modules with accurate status tracking
- Complete setup in one run
- Provide comprehensive final status report

### Existing Installation
```bash
sudo su - sciminer
bash SETUP_INFRASTRUCTURE_FINAL.sh
```
The script will:
- Detect existing services
- Offer options to keep or reinstall components
- Prompt for database configuration or reconfiguration
- Install any missing Perl modules
- Update CGI scripts to use system Perl

### Testing/Preview Mode (Non-sudo)
```bash
su - sciminer
bash SETUP_INFRASTRUCTURE_FINAL.sh
```
The script will:
- Check prerequisites
- Skip operations requiring sudo
- Provide clear instructions for sudo execution
- Allow preview of what will be done

## Configuration Files
- Apache: `/etc/apache2/sites-available/sciminer.conf`
- SciMiner: `/home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini`
- Database: Configured via script with credentials:
  - Database: `sciminer`
  - Username: `sciminer`
  - Password: `124356!@`

## Testing After Installation

### Basic Tests
```bash
# Test web server
curl http://localhost:8888/

# Test SciMiner
curl http://localhost:8888/SciMiner/
```

### Advanced Tests
```bash
# Check Apache status
systemctl status apache2

# Check MariaDB status
systemctl status mariadb

# Verify database connection
mysql -u sciminer -p'124356!@' sciminer -e "SHOW TABLES;"
```

## Troubleshooting

### If Perl modules were not installed:
```bash
sudo bash /home/sciminer/INSTALL_PERL_MODULES.sh
```

### If database needs configuration:
```bash
sudo bash /home/sciminer/CONFIGURE_DATABASE.sh
```

### Common Issues

1. **Permission denied errors**:
   - Ensure running as sciminer user with sudo access
   - Check file ownership: `sudo chown -R sciminer:sciminer /home/sciminer`

2. **Database connection failures**:
   - Verify MariaDB is running: `systemctl status mariadb`
   - Test credentials manually with mysql command
   - Check if database was created: `mysql -u root -p -e "SHOW DATABASES;"`

3. **Apache not serving CGI**:
   - Check error log: `tail /var/log/apache2/sciminer_error.log`
   - Verify module is enabled: `sudo a2enmod cgid`
   - Restart Apache: `sudo systemctl restart apache2`

4. **Perl module issues**:
   - Check system Perl location: `which perl`
   - Verify module installation: `perl -MModule::Name -e '1'`
   - Check @INC path: `perl -e 'print join("\n", @INC)'`
   - If Boulder::Medline permission denied: Move local copy to Archive, use system version

### Log Files
- Apache error log: `/var/log/apache2/sciminer_error.log`
- Apache access log: `/var/log/apache2/sciminer_access.log`
- MariaDB log: `/var/log/mysql/error.log`

## Default Credentials
- Database user: `sciminer`
- Database password: `124356!@`
- Web port: `8888`
- System user: `sciminer`

⚠️ **Security Note**: For production deployments:
- Change default database password
- Consider using a non-standard web port
- Implement firewall rules
- Regular security updates
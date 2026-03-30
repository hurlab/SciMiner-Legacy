# SciMiner Installation Options

## Overview

SciMiner offers three installation approaches to suit different needs:

### Option 1: Two-Stage Installation (Recommended)
Best for production and when you have existing infrastructure.

**Stage 1: Infrastructure Setup**
```bash
sudo bash ./SETUP_INFRASTRUCTURE.sh
```
- Interactive - asks before overwriting existing installations
- Flexible - works with existing Apache/MariaDB
- Comprehensive - handles database creation and schema import
- Safe - creates backups before making changes

**Stage 2: Perl Module Installation**
```bash
sudo bash ./INSTALL_PERL_MODULES.sh
```
- Fast - assumes infrastructure is ready
- Complete - installs all required modules
- Automatic - fixes known issues
- Verifying - runs comprehensive tests

### Option 2: One-Command Installation
Best for fresh systems and automated deployment.

```bash
sudo bash ./INSTALL_SCIMINER_COMPLETE.sh
```
- All-in-one - installs everything in one go
- Automated - no user interaction required
- Comprehensive - includes all fixes and configurations
- Quick - single command deployment

### Option 3: Manual Installation
Best for custom setups and troubleshooting.

Follow [COMPLETE_INSTALLATION_GUIDE.md](COMPLETE_INSTALLATION_GUIDE.md) for step-by-step instructions.

## Choosing the Right Option

### Use Two-Stage Installation When:
- You already have Apache or MariaDB installed
- You want to review infrastructure changes before proceeding
- You need to customize database settings
- You're installing in production with existing services
- You want to verify each stage independently

### Use One-Command Installation When:
- You have a fresh Ubuntu 24.04 system
- You want to automate deployment
- You're confident with all default settings
- You're doing testing or development
- You want the fastest installation

### Use Manual Installation When:
- You need to understand each step
- You're debugging issues
- You have custom requirements
- You're on a different Linux distribution

## Prerequisites for All Options

- Ubuntu 24.04 (or newer)
- Root/sudo access
- Internet connection
- sciminer.sql file in current directory (for database schema)

## After Installation

Regardless of installation method:
1. Access SciMiner at: http://localhost:8888/SciMiner/
2. Verify installation: `./check_system_perl_modules.pl`
3. Check logs if needed: `tail -f /var/log/apache2/sciminer_error.log`
4. **IMPORTANT**: Change default database password for production!

## Customization

You can customize these environment variables before running any script:

```bash
export SCIMINER_HOME=/path/to/sciminer    # Default: /home/sciminer
export WEB_PORT=8080                       # Default: 8888
export DB_NAME=my_sciminer                 # Default: sciminer
export DB_USER=myuser                      # Default: sciminer
export DB_PASS=mypassword                  # Default: 124356!@

# Then run your chosen installation script
```

## Summary Table

| Feature | Two-Stage | One-Command | Manual |
|---------|-----------|-------------|---------|
| User Interaction | Yes (Stage 1) | No | Yes |
| Existing Infrastructure | Supported | Overwrites | Flexible |
| Best For | Production | Fresh Systems | Custom Needs |
| Installation Time | 5-10 min + 5-10 min | 10-15 min | Variable |
| Customization | High | Low | Highest |
| Troubleshooting | Easier | Harder | Easiest |
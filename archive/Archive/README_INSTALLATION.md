# SciMiner System Perl Installation

## Two-Stage Installation

This installation is split into two stages for flexibility and better control:

### Stage 1: Infrastructure Setup
```bash
sudo bash ./SETUP_INFRASTRUCTURE.sh
```

This script will:
- ✅ Install/Configure Apache web server
- ✅ Install/Configure MariaDB database (no configuration)
- ✅ Create Apache virtual host configuration
- ✅ Set proper permissions
- ✅ Create test page to verify Apache is working

**Note**: This script is interactive and will ask for confirmation if Apache/MariaDB are already installed.

### Stage 1.5: Database Configuration (Optional)
```bash
sudo bash ./CONFIGURE_DATABASE.sh
```

This script will:
- ✅ Prompt for database admin credentials
- ✅ Create 'sciminer' database and user
- ✅ Import sciminer.sql schema (if available)
- ✅ Update SciMiner configuration file

**Note**: This can be run anytime after Stage 1 to configure or reconfigure the database.

### Stage 2: Perl Module Installation
```bash
sudo bash ./INSTALL_PERL_MODULES.sh
```

This script will:
- ✅ Install build tools and development headers
- ✅ Install Perl packages via apt
- ✅ Install missing modules via CPAN
- ✅ Fix Boulder::Medline syntax errors
- ✅ Update all CGI scripts to use system Perl
- ✅ Run comprehensive verification tests

## One-Command Installation (Alternative)

If you prefer a single script that does everything:
```bash
sudo bash ./INSTALL_SCIMINER_COMPLETE.sh
```

## After Installation

Access SciMiner at: http://localhost:8888/SciMiner/

## Documentation

- **Complete Guide**: [COMPLETE_INSTALLATION_GUIDE.md](COMPLETE_INSTALLATION_GUIDE.md)
- **Module Locations**: [PERL_MODULE_LOCATIONS.md](PERL_MODULE_LOCATIONS.md)

## Testing

Verify installation:
```bash
./check_system_perl_modules.pl
```

## Requirements

- Ubuntu 24.04 (or newer)
- Root/sudo access
- Internet connection for package downloads

## Default Configuration

- **Web Port**: 8888
- **Database**: MariaDB
- **Database Name**: sciminer
- **Database User**: sciminer
- **Database Password**: 124356!@ (CHANGE FOR PRODUCTION!)

---

**Note**: This installation uses system Perl instead of conda for better distribution and maintenance.
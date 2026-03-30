# SciMiner Setup Guide (Conda Environment)

This guide provides step-by-step instructions for setting up SciMiner using Conda environment management on Ubuntu/Debian Linux systems.

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Conda Environment Setup](#conda-environment-setup)
3. [Required Perl Packages](#required-perl-packages)
4. [Apache Web Server Configuration](#apache-web-server-configuration)
5. [Database Setup](#database-setup)
6. [File Permissions](#file-permissions)
7. [Code Modifications](#code-modifications)
8. [Testing the Installation](#testing-the-installation)
9. [Troubleshooting](#troubleshooting)

## System Requirements

- **OS**: Ubuntu 20.04+ / Debian 10+
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 10GB free space
- **Database**: MySQL 5.7+ or MariaDB 10.3+
- **Conda**: Miniconda3 or Anaconda3

## Conda Environment Setup

### 1. Activate SciMiner Environment
```bash
# If environment doesn't exist, create it first
conda create -n sciminer perl=5.40 -y

# Activate the environment
conda activate sciminer
```

### 2. Install System Dependencies
```bash
# Install compilers and essential tools
conda install -y make gcc_linux-64 gxx_linux-64
conda install -y libxml2 libxslt expat

# Install cpanm (if not already installed)
curl -L https://cpanmin.us | perl - App::cpanminus
```

## Required Perl Packages

### Required Perl Modules List:
```
Boulder::Medline
YAML
YAML::XS
Text::NSP
CGI::Debug
CGI::Simple
CGI::Session
CGI::Application
HTML::Template
Data::Dumper
Unicode::String
XML::XPath
XML::Parser
XML::LibXML
Spreadsheet::WriteExcel
```

### Database Modules Installation
```bash
# FIRST install conda-forge packages for database support
conda install -c conda-forge libxcrypt
conda install -c conda-forge perl-dbd-mysql
conda install -c conda-forge perl-dbd-sqlite

# THEN install DBI with force flag
cpanm DBI --force

# Install other required modules
cpanm -i YAML YAML::XS Text::NSP Data::Dumper Spreadsheet::WriteExcel

# Install XML modules
cpanm -i XML::LibXML

# Install CGI-related modules
cpanm -i CGI CGI::Session HTML::Template

# Note: Some modules may still need system packages
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl
```

### Alternative Installation Methods:
```bash
# For modules that fail via cpanm, try using conda-forge
conda install -c conda-forge perl-yaml perl-xml-libxml

# Or install manually from CPAN
perl -MCPAN -e 'install Module::Name'
```

## Apache Web Server Configuration

### 1. Install Apache (system-wide)
```bash
sudo apt-get update
sudo apt-get install -y apache2
```

### 2. Configure Apache for Conda Perl
Create `/etc/apache2/sites-available/sciminer.conf`:

```apache
<VirtualHost *:8888>
    ServerName localhost
    ServerAdmin admin@localhost

    # Document root for SciMiner
    DocumentRoot /home/sciminer/web/html

    # Use Conda Perl environment
    PerlSwitches -I/home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl
    SetEnv PERL5LIB /home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl
    SetEnv PATH /home/sciminer/miniconda3/envs/sciminer/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Directory configuration
    <Directory /home/sciminer/web/html>
        Options Indexes FollowSymLinks ExecCGI
        AllowOverride None
        Require all granted
    </Directory>

    # Enable CGI for .cgi files
    <Directory "/home/sciminer/web/html/SciMiner">
        Options +ExecCGI
        AddHandler cgi-script .cgi .pl
        Require all granted
    </Directory>

    # DirectoryIndex
    DirectoryIndex index.html index.htm

    # Error and access logs
    ErrorLog ${APACHE_LOG_DIR}/sciminer_error.log
    CustomLog ${APACHE_LOG_DIR}/sciminer_access.log combined

    # Additional environment for SciMiner
    SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules:/home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl
</VirtualHost>
```

### 3. Configure Apache Port
Edit `/etc/apache2/ports.conf`:
```apache
Listen 8888
```

### 4. Enable and Start Apache
```bash
sudo a2enmod cgi cgid
sudo a2dissite 000-default
sudo a2ensite sciminer
sudo systemctl restart apache2
```

## Database Setup

### 1. Install MySQL
```bash
sudo apt-get install -y mysql-server
```

### 2. Create Database
```bash
# Create database and user
sudo mysql -e "CREATE DATABASE sciminer CHARACTER SET latin1 COLLATE latin1_swedish_ci;"
sudo mysql -e "CREATE USER 'sciminer'@'localhost' IDENTIFIED BY 'your_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON sciminer.* TO 'sciminer'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Import schema (if you have the dump file)
mysql -u sciminer -p sciminer < sciminer.sql
```

### 3. Install DBD::MySQL in Conda
```bash
cpanm -i DBI DBD::MySQL
```

## File Permissions

```bash
# Make home directory accessible
chmod 755 /home/sciminer

# Set web directory permissions
chmod -R 755 /home/sciminer/web

# Make scripts executable
find /home/sciminer/web/html -name "*.cgi" -exec chmod +x {} \;
find /home/sciminer/web/html -name "*.pl" -exec chmod +x {} \;

# Create temp directory
mkdir -p /tmp/SciMiner
chmod 777 /tmp/SciMiner
```

## Code Modifications

### 1. Boulder::Medline Module Fix
Since Boulder is not available on CPAN, you need to:

**Option A: Find an alternative module**
Replace Boulder usage with:
```perl
use Bio::MedlineRecord;
# Or use XML::Twig for parsing PubMed XML
```

**Option B: Create a mock Boulder module**
Create `/home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl/Boulder/Medline.pm`:

```perl
package Boulder::Medline;

# Basic mock implementation
sub new {
    my $class = shift;
    return bless {}, $class;
}

sub parse_record {
    my $self = shift;
    # Implementation for parsing Medline records
    return {};
}

1;
```

### 2. Fix Line 274 in Medline.pm
If you have Boulder::Medline installed, fix the typo:
```bash
# Find the file
find /home/sciminer/miniconda3/envs/sciminer -name "Medline.pm" -type f

# Edit line 274
# Change: @recorlines[$i]
# To:     $recordlines[$i]
```

### 3. Update Shebang Lines
Ensure all Perl scripts use conda Perl:
```bash
# Update shebang in all CGI scripts
find /home/sciminer/web/html -name "*.cgi" -exec sed -i '1s|#!.*|#!/home/sciminer/miniconda3/envs/sciminer/bin/perl|' {} \;
```

## Testing the Installation

### 1. Create Test Script
Create `/home/sciminer/web/html/SciMiner/test_conda.cgi`:

```perl
#!/home/sciminer/miniconda3/envs/sciminer/bin/perl

print "Content-Type: text/plain\n\n";
print "Conda Environment Test\n";
print "====================\n\n";

print "Perl Version: $]\n";
print "Perl Path: $^X\n";
print "Perl Inc: @INC\n\n";

# Test modules
my @modules = qw(DBI DBD::MySQL CGI CGI::Session HTML::Template);
foreach my $module (@modules) {
    eval "use $module";
    if ($@) {
        print "FAIL: $module - $@\n";
    } else {
        print "OK: $module\n";
    }
}

# Test database connection
use DBI;
my $dsn = "DBI:mysql:database=sciminer;host=localhost";
eval {
    my $dbh = DBI->connect($dsn, 'sciminer', 'your_password');
    if ($dbh) {
        print "\nOK: Database connection successful\n";
        $dbh->disconnect();
    }
};
if ($@) {
    print "\nFAIL: Database connection - $@\n";
}
```

### 2. Test Web Access
```bash
# Test in browser or with curl
curl http://localhost:8888/SciMiner/test_conda.cgi
```

## Troubleshooting

### 1. Module Installation Failures

**IMPORTANT: For Database Modules (DBI/DBD):**
```bash
# CRITICAL: Install these in this specific order
conda install -c conda-forge libxcrypt
conda install -c conda-forge perl-dbd-mysql
conda install -c conda-forge perl-dbd-sqlite
cpanm DBI --force  # Use --force flag for DBI
```

**For Other Compilation Errors:**
```bash
# Install build tools
conda install -y gcc_linux-64 gxx_linux-64 make

# For XML errors
conda install -y expat libxml2

# For database errors, check MySQL is running
sudo systemctl status mysql
```

### 2. Apache + Conda Issues
```bash
# Check Apache error log
sudo tail -f /var/log/apache2/sciminer_error.log

# Ensure Perl path is correct in Apache config
which perl  # Should show: /home/sciminer/miniconda3/envs/sciminer/bin/perl
```

### 3. Permission Issues
```bash
# Fix script permissions
chmod +x /home/sciminer/web/html/SciMiner/*.cgi

# Fix directory permissions
chmod 755 /home/sciminer
```

### 4. Database Connection Issues
```bash
# Test MySQL connection
mysql -u sciminer -p sciminer

# Check DBD::MySQL
perl -MDBD::MySQL -e 'print "DBD::MySQL installed"'
```

## Automation Script

For automated installation, use the provided script:
```bash
# Run the conda-specific installation script
bash /home/sciminer/install_sciminer_conda.sh
```

## Maintenance

### 1. Activate Conda Environment for Maintenance
```bash
conda activate sciminer
```

### 2. Update Perl Modules
```bash
cpanm --self-upgrade
cpanm Module::Name  # Update specific module
```

### 3. Check Conda Environment
```bash
conda list  # List installed packages
conda env export > sciminer_env.yml  # Export environment
```

## Additional Notes

- Always activate the conda environment before running Perl scripts
- Apache needs to be configured to use the conda Perl binary
- Some legacy modules might not be available through conda/cpan and require alternatives
- Keep the conda environment isolated to avoid conflicts with system Perl
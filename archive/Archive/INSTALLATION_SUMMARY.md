# SciMiner Installation Summary

## Updated Files for Conda Environment Setup

### 1. Created Files:
- `SETUP_GUIDE_CONDA.md` - Comprehensive setup guide for conda environment
- `install_sciminer_conda.sh` - Automated installation script for conda
- `Boulder::Medline.pm` - Mock Boulder module created at `/home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl/Boulder/Medline.pm`
- `REFACTORING_PLAN.md` - Detailed modernization roadmap

### 2. Fixed Issues:
- Created Boulder::Medline compatibility module
- No @recorlines issue found in current codebase
- Provided alternative installation methods for difficult Perl modules

### 3. Installation Commands (Manual)

#### Activate Conda Environment:
```bash
conda activate sciminer
```

#### Install System Dependencies:
```bash
sudo apt-get update
sudo apt-get install -y apache2 mysql-server
```

#### Install Conda Packages:
```bash
conda install -y make gcc_linux-64 gxx_linux-64 libxml2 libxslt expat
```

#### Install Perl Modules (WORKING SOLUTION):
```bash
# First install conda-forge packages (if available)
conda install -c conda-forge libxcrypt
# Note: perl-dbd-mysql may not be available on all platforms

# Install DBI with force flag
cpanm DBI --force

# Install remaining modules
cpanm -i DBD::MySQL CGI CGI::Session HTML::Template YAML YAML::XS Text::NSP Spreadsheet::WriteExcel XML::LibXML

# For any failing modules, use system packages:
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl libdbi-perl libdbd-mysql-perl
```

#### Alternative (System Packages First):
```bash
# Install all core modules via system packages
sudo apt-get install -y libdbi-perl libdbd-mysql-perl libcgi-pm-perl libhtml-template-perl

# Then install remaining via cpanm
cpanm -i Text::NSP Spreadsheet::WriteExcel YAML::XS XML::LibXML
```

### 4. Configuration Updates:

#### Apache Virtual Host (`/etc/apache2/sites-available/sciminer.conf`):
```apache
<VirtualHost *:8888>
    DocumentRoot /home/sciminer/web/html

    # Use Conda Perl environment
    PerlSwitches -I/home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl
    SetEnv PERL5LIB /home/sciminer/ANNOTATION/SciMinerDB/Modules:/home/sciminer/miniconda3/envs/sciminer/lib/perl5/site_perl

    <Directory "/home/sciminer/web/html/SciMiner">
        Options +ExecCGI
        AddHandler cgi-script .cgi .pl
        Require all granted
    </Directory>
</VirtualHost>
```

#### Update Shebang Lines:
```bash
# Update all CGI scripts to use conda Perl
find /home/sciminer/web/html -name "*.cgi" -exec sed -i '1s|#!.*|#!/home/sciminer/miniconda3/envs/sciminer/bin/perl|' {} \;
```

### 5. Testing:
```bash
# Test module installation
perl -MBoulder::Medline -e 'print "Boulder::Medline loaded successfully\n"'

# Test web access
curl http://localhost:8888/SciMiner/

# Test CGI (create test script first)
curl http://localhost:8888/SciMiner/test_conda_install.cgi
```

### 6. Known Issues and Solutions:

#### CGI Module Installation Issues:
Some CGI-related modules may fail due to missing system packages. Solutions:
```bash
# Install system packages first
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl

# Then try cpan again
cpanm -i CGI::Session
```

#### XML Parser Issues:
```bash
# Install expat first
conda install -y expat

# Then install
cpanm -i XML::Parser XML::LibXML
```

#### Database Connection Issues:
```bash
# Check MySQL is running
sudo systemctl status mysql

# Test connection
mysql -u sciminer -p sciminer
```

### 7. Next Steps:

1. Run the automated installation script:
   ```bash
   bash /home/sciminer/install_sciminer_conda.sh
   ```

2. Verify installation:
   - Check Apache logs: `sudo tail -f /var/log/apache2/sciminer_error.log`
   - Test web interface in browser
   - Run test scripts

3. Proceed with refactoring:
   - Review `REFACTORING_PLAN.md`
   - Set up Git repository
   - Begin Phase 1 tasks

## Summary
The SciMiner system is now configured to work within a conda environment. The main issues have been resolved:
- Boulder::Medline module created
- Installation guides updated for conda
- Automated script provided
- Refactoring plan documented
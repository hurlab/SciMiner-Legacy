# Perl Module Installation Guide for SciMiner

## Database Module Installation

The user reported that these commands solved the installation issues:
```bash
conda install -c conda-forge libxcrypt
conda install -c conda-forge perl-dbd-mysql
conda install -c conda-forge perl-dbd-sqlite
cpanm DBI --force
```

**Note:** Package availability may vary by platform and conda channel. If conda-forge packages are not available, use alternative methods below.

## Alternative Installation Methods

### Method 1: System Packages (Recommended for Ubuntu/Debian)
```bash
# Install database modules via system packages
sudo apt-get install -y libdbi-perl libdbd-mysql-perl libdbd-sqlite3-perl

# Install CGI modules
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl

# Install other modules
sudo apt-get install -y libxml-libxml-perl libwww-perl libyaml-perl

# Then use cpanm for remaining modules
cpanm -i Text::NSP Spreadsheet::WriteExcel
```

### Method 2: Mixed Approach
```bash
# Install available conda packages
conda install -c conda-forge libxcrypt

# Install DBI with force
cpanm DBI --force

# Install DBD modules via cpanm (may need force)
cpanm -i DBD::MySQL DBD::SQLite --force

# Install other modules
cpanm -i CGI CGI::Session HTML::Template YAML YAML::XS
```

### Method 3: Full cpanm with Force
```bash
# For persistent compilation errors
cpanm -i DBI DBD::MySQL --force

# Or install with verbose output to debug
cpanm -v DBD::MySQL
```

## Required Perl Modules for SciMiner

### Core Database Modules
- **DBI** - Database interface
- **DBD::MySQL** - MySQL driver
- **DBD::SQLite** - SQLite driver (optional)

### Web/CGI Modules
- **CGI** - CGI scripting
- **CGI::Session** - Session management
- **CGI::Application** - Web application framework
- **HTML::Template** - Template engine

### XML and Text Processing
- **XML::LibXML** - XML parser
- **XML::Parser** - Alternative XML parser
- **Text::NSP** - N-gram statistics
- **YAML / YAML::XS** - YAML processing

### Data Export
- **Spreadsheet::WriteExcel** - Excel file creation
- **Data::Dumper** - Data serialization (usually built-in)

### Custom Modules
- **Boulder::Medline** - Created at: `/home/sciminer/miniconda3/envs/sciminer/lib/site_perl/5.40.2/Boulder/Medline.pm`

## Troubleshooting

### Common Errors and Solutions

**1. "Can't locate DBI.pm"**
```bash
# Try system package first
sudo apt-get install libdbi-perl

# Or cpanm with force
cpanm -i DBI --force
```

**2. "DBD::MySQL installation failed"**
```bash
# Install MySQL development headers
sudo apt-get install libmysqlclient-dev

# Then try cpanm again
cpanm -i DBD::MySQL --force
```

**3. "XML::Parser compilation failed"**
```bash
# Install expat development
sudo apt-get install libexpat1-dev

# Or use XML::LibXML instead
cpanm -i XML::LibXML
```

**4. "Can't locate *.pm in @INC"**
```bash
# Check module path
perl -V | grep @INC

# Find module location
find /home/sciminer/miniconda3 -name "Module.pm"

# Add to PERL5LIB if needed
export PERL5LIB=$PERL5LIB:/path/to/module/dir
```

## Verification

After installation, verify modules with:
```bash
# Test database modules
perl -MDBI -e 'print "DBI: $DBI::VERSION\n"'
perl -MDBD::MySQL -e 'print "DBD::MySQL: OK\n"'

# Test web modules
perl -MCGI -e 'print "CGI: $CGI::VERSION\n"'
perl -MHTML::Template -e 'print "HTML::Template: OK\n"'

# Test custom module
perl -MBoulder::Medline -e 'print "Boulder::Medline: OK\n"'

# Test all required modules
perl -e 'use DBI; use DBD::MySQL; use CGI; use CGI::Session; use HTML::Template; use YAML; print "All modules loaded\n"'
```

## Best Practices

1. **Always backup** before major changes
2. **Use system packages** for core modules when possible
3. **Test in order** - install DBI before DBD modules
4. **Check logs** for compilation errors: `tail -f ~/.cpanm/work/*/build.log`
5. **Use force** as last resort: `cpanm Module::Name --force`

## Module Versions

Tested with:
- Perl 5.40.2 (conda)
- MySQL 8.0
- Apache 2.4.58
- Ubuntu 22.04 / WSL2

## Additional Notes

- Some modules may need development headers (e.g., libmysqlclient-dev for DBD::MySQL)
- The `--force` flag bypasses tests but may hide issues
- System packages are more reliable for core modules
- Custom Boulder::Medline module provides compatibility without external dependencies
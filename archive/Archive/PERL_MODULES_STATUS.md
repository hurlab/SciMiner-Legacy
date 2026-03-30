# SciMiner Perl Modules Status Report

## Module Status Summary

Based on the latest test, here are the current statuses of all required Perl modules:

### ✅ Successfully Installed Modules (9/15)

| Module | Version | Status | Notes |
|--------|---------|--------|-------|
| DBI | 1.647 | ✅ Working | Core database interface |
| CGI | 4.71 | ✅ Working | CGI scripting framework |
| CGI::Session | 4.48 | ✅ Working | Session management |
| HTML::Template | 2.97 | ✅ Working | Template engine |
| YAML | 1.31 | ✅ Working | YAML processing |
| Text::NSP | 1.31 | ✅ Working | N-gram statistics |
| Spreadsheet::WriteExcel | 2.40 | ✅ Working | Excel file creation |
| Data::Dumper | 2.189 | ✅ Working | Data serialization (built-in) |
| Boulder::Medline | N/A | ✅ Working | Custom module created |

### ❌ Failed to Install Modules (6/15)

| Module | Status | Error | Solution |
|--------|--------|-------|----------|
| DBD::MySQL | ❌ FAILED | "Can't locate DBD/MySQL.pm" | Install via system package |
| DBD::SQLite | ❌ FAILED | Module not found | Install via conda/cpanm |
| CGI::Application | ❌ FAILED | Dependencies failed | Install via system package |
| YAML::XS | ❌ FAILED | Compilation failed | Install via system package |
| XML::LibXML | ❌ FAILED | Configuration failed | Install via system package |
| XML::Parser | ❌ FAILED | Configure failed | Install via system package |

## Detailed Installation Commands

### Critical Modules (Must Install)

#### 1. DBD::MySQL (CRITICAL - Required for database access)
```bash
# Option A: System package (RECOMMENDED)
sudo apt-get install -y libdbd-mysql-perl libmysqlclient-dev

# Option B: Install development headers first
sudo apt-get install -y libmysqlclient-dev
cpanm DBD::MySQL

# Option C: With MariaDB (if switching)
sudo apt-get install -y libdbd-mariadb-perl libmariadb-dev
cpanm DBD::MariaDB
```

#### 2. DBD::SQLite (Optional - for local testing)
```bash
# Via conda
conda install -c conda-forge perl-dbd-sqlite

# Via cpanm (after SQLite dev packages)
sudo apt-get install -y libsqlite3-dev
cpanm -i DBD::SQLite
```

### Important Modules (Recommended)

#### 3. CGI::Application (Optional - Web framework)
```bash
# System package
sudo apt-get install -y libcgi-application-perl

# Or via cpanm
cpanm -i CGI::Application
```

#### 4. YAML::XS (Optional - Faster YAML)
```bash
# System package
sudo apt-get install -y libyaml-libyaml-perl

# Or via conda
conda install -c conda-forge perl-yaml-xs

# Or via cpanm (with libyaml dev)
sudo apt-get install -y libyaml-dev
cpanm -i YAML::XS
```

#### 5. XML::LibXML (Optional - XML processing)
```bash
# System package
sudo apt-get install -y libxml-libxml-perl libxml2-dev

# Or via conda
conda install -c conda-forge perl-xml-libxml

# Or via cpanm
cpanm -i XML::LibXML
```

#### 6. XML::Parser (Optional - Alternative XML parser)
```bash
# Install expat first
sudo apt-get install -y libexpat1-dev

# Then install
cpanm -i XML::Parser
```

## Installation Script for All Missing Modules

Here's a script to install all missing modules:

```bash
#!/bin/bash
# install_missing_modules.sh

echo "Installing missing Perl modules for SciMiner..."

# Update system
sudo apt-get update

# Install all system packages for Perl modules
echo "Installing system packages..."
sudo apt-get install -y \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    libcgi-application-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libexpat1-dev \
    libmysqlclient-dev \
    libsqlite3-dev \
    libyaml-dev \
    libxml2-dev

# Try conda for any missing modules
echo "Installing via conda..."
conda install -c conda-forge perl-dbd-sqlite perl-yaml-xs perl-xml-libxml -y

# Try cpanm for anything still missing
echo "Installing via cpanm..."
cpanm -i CGI::Application YAML::XS XML::LibXML XML::Parser DBD::SQLite

echo "Installation complete!"
echo "Run /home/sciminer/test_current_status.pl to verify"
```

## Module Priority Level

### Critical (Required for basic functionality)
- **DBD::MySQL** - Without this, no database access
- Status: ❌ FAILED

### High (Required for full functionality)
- **CGI::Application** - Web application framework
- **XML::LibXML** - XML parsing for PubMed data
- Status: ❌ FAILED for both

### Medium (Optional but recommended)
- **YAML::XS** - Faster YAML processing (5-10x faster than YAML)
- **XML::Parser** - Alternative XML parser
- **DBD::SQLite** - For local testing/development
- Status: ❌ FAILED for all

### Low (Nice to have)
- None - all other modules are installed

## Troubleshooting Failed Modules

### General Troubleshooting Steps
```bash
# 1. Check if module is available via apt-cache
apt-cache search perl-module-name

# 2. Check specific error in cpanm log
tail -f ~/.cpanm/work/*/build.log

# 3. Install with verbose output
cpanm -v Module::Name

# 4. Force install (last resort)
cpanm -f Module::Name
```

### Specific Module Issues

#### DBD::MySQL
```bash
# Check MySQL/MariaDB client
which mysql
mysql --version

# Install MySQL client libraries
sudo apt-get install -y libmysqlclient20

# Reinstall with force
cpanm -f --reinstall DBD::MySQL
```

#### XML Modules
```bash
# Install XML libraries
sudo apt-get install -y libxml2-dev libxslt1-dev

# Clean cpanm cache
cpanm --uninstall XML::LibXML XML::Parser
cpanm -i XML::LibXML XML::Parser
```

#### YAML::XS
```bash
# Install LibYAML
sudo apt-get install -y libyaml-dev

# Force reinstall
cpanm -f --reinstall YAML::XS
```

## Verification Script

Create a test script to verify all modules:

```perl
#!/usr/bin/perl
# verify_all_modules.pl

use strict;
use warnings;

my @modules = (
    ['DBI', 'Core database interface'],
    ['DBD::MySQL', 'MySQL/MariaDB driver'],
    ['DBD::SQLite', 'SQLite driver'],
    ['CGI', 'CGI scripting'],
    ['CGI::Session', 'Session management'],
    ['CGI::Application', 'Web framework'],
    ['HTML::Template', 'Template engine'],
    ['YAML', 'YAML parser'],
    ['YAML::XS', 'Fast YAML parser'],
    ['Text::NSP', 'N-gram statistics'],
    ['XML::LibXML', 'XML DOM parser'],
    ['XML::Parser', 'XML SAX parser'],
    ['Spreadsheet::WriteExcel', 'Excel writer'],
    ['Data::Dumper', 'Data serialization'],
    ['Boulder::Medline', 'Medline parser'],
);

print "SciMiner Module Verification\n";
print "============================\n\n";

my $ok = 0;
my $fail = 0;

for my $module (@modules) {
    my ($name, $desc) = @$module;

    eval "use $name";
    if ($@) {
        print "❌ $name - FAILED\n";
        print "   Description: $desc\n";
        print "   Error: $@\n\n";
        $fail++;
    } else {
        no strict 'refs';
        my $version = ${"${name}::VERSION"} || 'N/A';
        print "✅ $name - OK (v$version)\n";
        print "   Description: $desc\n\n";
        $ok++;
    }
}

print "Summary:\n";
print "--------\n";
print "Success: $ok\n";
print "Failed:  $fail\n";
print "Total:   " . ($ok + $fail) . "\n";
```

## Alternative Approach: Use Docker

If local installation continues to be problematic, consider using Docker:

```dockerfile
FROM perl:5.40

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    libcgi-application-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    mariadb-client

# Install Perl modules
RUN cpanm -i \
    DBI \
    DBD::MySQL \
    DBD::SQLite \
    CGI::Session \
    Text::NSP \
    Spreadsheet::WriteExcel

COPY . /app
WORKDIR /app
CMD ["perl", "test_current_status.pl"]
```

## Recommendations

1. **Install DBD::MySQL immediately** - This is critical for database access
2. **Install XML::LibXML** - Important for PubMed XML parsing
3. **Install YAML::XS** - Will significantly improve performance
4. **Others are optional** - System will work without them

## Next Steps

1. Run the installation script above
2. Verify with: `/home/sciminer/test_current_status.pl`
3. Test database connection
4. Test SciMiner web interface
5. Begin refactoring as planned in REFACTORING_PLAN.md
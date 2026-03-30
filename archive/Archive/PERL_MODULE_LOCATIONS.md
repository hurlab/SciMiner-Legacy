# Perl Module Installation Locations on Ubuntu 24.04

## System Perl Module Paths

When using system Perl (`/usr/bin/perl`), modules are installed in these directories:

### Primary Installation Paths
```bash
/usr/lib/x86_64-linux-gnu/perl5/5.38/          # Core and vendor modules
/usr/share/perl5/                             # Shared modules
/usr/lib/x86_64-linux-gnu/perl/5.38/          # Version-specific modules
/usr/share/perl/5.38/                         # Version-specific shared modules
/usr/local/lib/x86_64-linux-gnu/perl/5.38.2/  # CPAN/Self-installed modules
/usr/local/share/perl/5.38.2/                 # CPAN/Self-installed shared modules
```

### Module Location Examples

#### System-installed modules (via apt):
- **DBI**: `/usr/lib/x86_64-linux-gnu/perl5/5.38/DBI.pm`
- **DBD::MySQL**: `/usr/lib/x86_64-linux-gnu/perl5/5.38/DBD/mysql.pm`
- **CGI**: `/usr/share/perl/5.38/CGI.pm`
- **YAML**: `/usr/share/perl5/YAML.pm`
- **XML::LibXML**: `/usr/lib/x86_64-linux-gnu/perl/5.38/XML/LibXML.pm`

#### CPAN-installed modules (via cpanm):
- **Boulder**: `/usr/local/share/perl/5.38.2/Boulder/`
- **Boulder::Medline**: `/usr/local/share/perl/5.38.2/Boulder/Medline.pm`
- **Text::NSP**: `/usr/local/lib/x86_64-linux-gnu/perl/5.38.2/Text/NSP/`

## Finding Module Locations

### Using PERL2PM
```bash
# Find any module
perldoc -l Module::Name

# Examples:
perldoc -l DBI
perldoc -l Boulder::Medline
```

### Using find
```bash
# Find module by name
find /usr -name "Module.pm" 2>/dev/null

# Find all modules in a directory
find /usr/share/perl5 -name "*.pm" | head -10
```

### Using Perl itself
```bash
# Get @INC paths
perl -V | grep "@INC:"

# Find module location
perl -MModule::Name -e 'print $INC{"Module/Name.pm"} . "\n"'
```

## Module Installation Order

The `@INC` array determines the search order:

1. `/etc/perl` - Site-specific configuration
2. `/usr/local/lib/x86_64-linux-gnu/perl/5.38.2` - Local/Cpanm modules (FIRST)
3. `/usr/local/share/perl/5.38.2` - Local shared modules
4. `/usr/lib/x86_64-linux-gnu/perl5/5.38` - System vendor modules
5. `/usr/share/perl5` - System shared modules
6. `/usr/lib/x86_64-linux-gnu/perl-base` - Base modules
7. `/usr/lib/x86_64-linux-gnu/perl/5.38` - Version-specific modules
8. `/usr/share/perl/5.38` - Version-specific shared modules
9. `/usr/local/lib/site_perl` - Site modules
10. `.` - Current directory

## Key Points

1. **CPAN/cpanm modules** go in `/usr/local/lib/...` or `/usr/local/share/...`
2. **apt packages** go in `/usr/lib/...` or `/usr/share/...`
3. **Local modules** override system modules if in `/usr/local/`
4. **Boulder::Medline** was installed at `/usr/local/share/perl/5.38.2/Boulder/`

## Common Module Commands

```bash
# List all installed modules
find /usr -name "*.pm" -type f 2>/dev/null | wc -l

# Check if a module is installed
perl -MModule::Name -e 'print "Installed\n"'

# Get module version
perl -MModule::Name -e 'print "$Module::Name::VERSION\n"'

# Reinstall a module
cpanm --force Module::Name
```

## SciMiner Specific

For SciMiner deployment, ensure modules are available in system paths:
- Use system Perl: `#!/usr/bin/perl`
- Set PERL5LIB if needed: `export PERL5LIB=/usr/local/share/perl/5.38.2:/usr/local/lib/x86_64-linux-gnu/perl/5.38.2`
- Apache automatically includes system paths for system Perl

This explains why the modules work with system Perl but weren't visible when using conda Perl - they're installed in completely different directory trees!
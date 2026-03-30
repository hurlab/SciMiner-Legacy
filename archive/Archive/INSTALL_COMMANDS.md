# Direct Installation Commands for Ubuntu 24.04

Since the automated scripts had issues with package checking, here are the direct commands to install all required Perl packages:

## Step 1: Install Build Tools and Development Headers
```bash
sudo apt-get update
sudo apt-get install -y build-essential gcc make libxml2-dev libyaml-dev
```

## Step 2: Install Available Perl Packages
```bash
sudo apt-get install -y \
    libdbi-perl \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    libcgi-pm-perl \
    libyaml-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libjson-perl \
    libjson-xs-perl \
    libhtml-template-perl \
    libwww-perl \
    liburi-perl \
    libcgi-session-perl
```

## Step 3: Try to Install Optional Packages
```bash
sudo apt-get install -y \
    libspreadsheet-writeexcel-perl \
    libcgi-application-perl || echo "These packages are not available, will install via CPAN"
```

## Step 4: Install CPAN and Missing Modules
```bash
# Install cpanminus
sudo apt-get install -y cpanminus || sudo cpan App::cpanminus

# Install Text::NSP (not in Ubuntu repo)
sudo cpanm --notest Text::NSP

# Install modules that failed to install via apt
for module in "CGI::Application" "Spreadsheet::WriteExcel" "Boulder::Medline"; do
    if ! perl -M"$module" -e '1' 2>/dev/null; then
        sudo cpanm --notest "$module"
    fi
done
```

## Step 5: Verify Installation
```bash
/home/sciminer/check_system_perl_modules.pl
```

## All-in-One Command
If you want to run everything at once (as root):

```bash
#!/bin/bash
apt-get update
apt-get install -y build-essential gcc make libxml2-dev libyaml-dev
apt-get install -y libdbi-perl libdbd-mysql-perl libdbd-sqlite3-perl libcgi-pm-perl \
    libyaml-perl libyaml-libyaml-perl libxml-libxml-perl libxml-parser-perl \
    libjson-perl libjson-xs-perl libhtml-template-perl libwww-perl \
    liburi-perl libcgi-session-perl
apt-get install -y libspreadsheet-writeexcel-perl libcgi-application-perl || true
apt-get install -y cpanminus || cpan App::cpanminus
cpanm --notest Text::NSP
for module in "CGI::Application" "Spreadsheet::WriteExcel" "Boulder::Medline"; do
    perl -M"$module" -e '1' 2>/dev/null || cpanm --notest "$module"
done
/home/sciminer/check_system_perl_modules.pl
```

This should work on Ubuntu 24.04 without any package availability checking issues.
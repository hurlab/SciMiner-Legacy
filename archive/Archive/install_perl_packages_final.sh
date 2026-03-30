#!/bin/bash
# Simple Perl package installation script for SciMiner
# Works on Ubuntu 24.04

echo "Installing Perl packages for SciMiner..."

# Update package list
sudo apt-get update

# Install confirmed working packages from Ubuntu 24.04
echo "Installing system packages..."
sudo apt-get install -y \
    build-essential \
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

# Try to install packages that might have different names
echo "Installing additional packages..."
sudo apt-get install -y \
    libspreadsheet-writeexcel-perl \
    libcgi-application-perl || echo "Some packages not found in repository"

# Install cpanminus for CPAN modules
sudo apt-get install -y cpanminus || sudo cpan App::cpanminus

# Install Text::NSP via CPAN (not in Ubuntu repo)
echo "Installing Text::NSP via CPAN..."
sudo cpanm --notest Text::NSP

# Install any other missing modules via CPAN
echo "Installing other modules via CPAN as needed..."
for module in "CGI::Application" "Spreadsheet::WriteExcel" "Boulder::Medline"; do
    if ! perl -M"$module" -e '1' 2>/dev/null; then
        echo "Installing $module via CPAN..."
        sudo cpanm --notest "$module"
    fi
done

echo ""
echo "Checking installation status..."
/home/sciminer/check_system_perl_modules.pl

echo ""
echo "Installation complete!"
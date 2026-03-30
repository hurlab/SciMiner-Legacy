#!/bin/bash
# Quick installation for SciMiner on Ubuntu 24.04
# This script addresses the package availability issues in Ubuntu 24.04

echo "SciMiner Quick Installation for Ubuntu 24.04"
echo "=============================================="

# Update package list
echo "Updating package list..."
sudo apt-get update

# Install build tools
echo "Installing build tools..."
sudo apt-get install -y build-essential gcc make

# Install available Perl packages
echo "Installing Perl packages available in Ubuntu 24.04..."
sudo apt-get install -y \
    libyaml-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libspreadsheet-writeexcel-perl \
    libjson-perl \
    libcgi-application-perl \
    libdbd-sqlite3-perl \
    libcgi-session-perl

# Install cpanminus if needed
if ! command -v cpanm >/dev/null 2>&1; then
    echo "Installing cpanminus..."
    sudo apt-get install -y cpanminus || sudo cpan App::cpanminus
fi

# Install modules not available in Ubuntu 24.04
echo "Installing modules via CPAN..."
sudo cpanm --notest Text::NSP

# Optional: Install YAML::XS via CPAN if system package fails
if ! perl -MYAML::XS -e '1' 2>/dev/null; then
    echo "Installing YAML::XS via CPAN..."
    sudo cpanm --notest YAML::XS
fi

# Verify installation
echo ""
echo "Verification:"
echo "============="
/usr/bin/perl /home/sciminer/check_system_perl_modules.pl

echo ""
echo "Installation completed!"
echo "Note: Text::NSP was installed via CPAN as it's not available in Ubuntu 24.04"
#!/bin/bash
# Script to install required system Perl packages for SciMiner

echo "Installing SciMiner system Perl dependencies..."

# Update package lists
sudo apt-get update

# First, install build tools required for compilation
echo "Installing build tools..."
sudo apt-get install -y \
    build-essential \
    pkg-config \
    gcc \
    make \
    libc6-dev

# Install development headers for XML and YAML libraries
echo "Installing development headers..."
sudo apt-get install -y \
    libxml2-dev \
    libyaml-dev \
    zlib1g-dev \
    libmysqlclient-dev

# Install core Perl packages
echo "Installing Perl packages..."
sudo apt-get install -y \
    libyaml-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libtext-nsp-perl \
    libspreadsheet-writeexcel-perl \
    libjson-perl \
    libcgi-application-perl \
    libdbd-sqlite3-perl \
    libcgi-session-perl

echo "All required Perl packages have been installed!"

# Verify installation
echo ""
echo "Verifying installed packages:"
for pkg in libyaml-perl libyaml-libyaml-perl libxml-libxml-perl libxml-parser-perl libtext-nsp-perl libspreadsheet-writeexcel-perl libjson-perl libcgi-application-perl libdbd-sqlite3-perl; do
    if dpkg -l | grep -q "^ii.*$pkg "; then
        echo "✓ $pkg is installed"
    else
        echo "✗ $pkg is NOT installed"
    fi
done
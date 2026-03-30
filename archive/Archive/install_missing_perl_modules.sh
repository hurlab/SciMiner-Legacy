#!/bin/bash

# Install Missing Perl Modules for SciMiner
# This script installs all failed Perl modules

set -e  # Exit on any error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Installing missing Perl modules for SciMiner..."

# Check if running as root for system packages
if [[ $EUID -ne 0 ]]; then
    print_warning "Some commands require sudo. Make sure sudo is available."
fi

# Update system packages
print_status "Updating system package list..."
sudo apt-get update

# Install all system packages for Perl modules
print_status "Installing system packages for Perl modules..."
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

# Try conda for any missing modules (if conda is available)
if command -v conda &> /dev/null; then
    print_status "Trying to install modules via conda..."
    conda install -c conda-forge perl-dbd-sqlite perl-yaml-xs perl-xml-libxml -y || true
fi

# Try cpanm for anything still missing
if command -v cpanm &> /dev/null; then
    print_status "Installing remaining modules via cpanm..."

    # Install with force if needed
    cpanm -i CGI::Application || print_warning "CGI::Application failed via cpanm"
    cpanm -i YAML::XS || print_warning "YAML::XS failed via cpanm"
    cpanm -i XML::LibXML || print_warning "XML::LibXML failed via cpanm"
    cpanm -i XML::Parser || print_warning "XML::Parser failed via cpanm"
    cpanm -i DBD::SQLite || print_warning "DBD::SQLite failed via cpanm"
else
    print_error "cpanm not found. Please install cpanm first:"
    echo "curl -L https://cpanmin.us | perl - App::cpanminus"
fi

# Special handling for DBD::MySQL/MariaDB
print_status "Checking database driver..."
if perl -MDBD::MySQL -e 1 2>/dev/null; then
    print_status "DBD::MySQL is already installed"
else
    print_warning "DBD::MySQL not found. Installing with force..."
    if command -v cpanm &> /dev/null; then
        cpanm -f DBD::MySQL || print_error "DBD::MySQL installation failed"
    fi
fi

print_status "Installation complete!"
echo ""
print_warning "To verify installation, run:"
echo "  /home/sciminer/test_current_status.pl"
echo ""
print_status "Or run the verification script:"
echo "  perl /home/sciminer/verify_all_modules.pl"
#!/bin/bash
set -euo pipefail

# Script to install required system Perl packages for SciMiner
# Updated and corrected for Ubuntu 24.04 compatibility

echo "Installing SciMiner system Perl dependencies for Ubuntu 24.04..."
sudo apt-get update

# Install build tools first
echo "Installing build tools..."
sudo apt-get install -y build-essential pkg-config gcc make libc6-dev

# Install development headers
echo "Installing development headers..."
sudo apt-get install -y libxml2-dev libyaml-dev zlib1g-dev libmysqlclient-dev

# Install Perl packages that are confirmed available in Ubuntu 24.04
echo "Installing Perl packages from apt..."
sudo apt-get install -y \
    libyaml-perl \
    libyaml-libyaml-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libjson-perl \
    libdbi-perl \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    libcgi-pm-perl \
    libcgi-session-perl \
    libhtml-template-perl \
    libwww-perl \
    liburi-perl \
    libjson-xs-perl

# Install packages that might not be available
echo "Installing additional packages..."
apt-get install -y \
    libcgi-application-perl \
    libspreadsheet-writeexcel-perl \
    libtext-nsp-perl || echo "Some packages not available, will install via CPAN"

# Install cpanminus if not present
if ! command -v cpanm >/dev/null 2>&1; then
    echo "Installing cpanminus..."
    sudo apt-get install -y cpanminus || sudo cpan App::cpanminus
fi

# Install modules not available or that failed to install via CPAN
echo "Installing missing modules via CPAN..."
for module in "Text::NSP" "CGI::Application" "Spreadsheet::WriteExcel"; do
    if ! perl -M"$module" -e '1' 2>/dev/null; then
        echo "  Installing $module via CPAN..."
        sudo cpanm --notest "$module" || echo "  Warning: Failed to install $module"
    fi
done

echo ""
echo "Verifying installation..."
echo "========================"
/usr/bin/perl /home/sciminer/check_system_perl_modules.pl

echo ""
echo "Installation completed!"
#!/bin/bash
set -euo pipefail

# Script to install required system Perl packages for SciMiner
# Updated for Ubuntu 24.04 compatibility

echo "Installing SciMiner system Perl dependencies..."
sudo apt-get update

# Install build tools first
echo "Installing build tools..."
sudo apt-get install -y build-essential pkg-config gcc make libc6-dev

# Install development headers
echo "Installing development headers..."
sudo apt-get install -y libxml2-dev libyaml-dev zlib1g-dev libmysqlclient-dev

# Install Perl packages that are available in Ubuntu 24.04
echo "Installing Perl packages from apt..."
APT_PKGS=(
    libyaml-perl
    libyaml-libyaml-perl
    libxml-libxml-perl
    libxml-parser-perl
    libspreadsheet-writeexcel-perl
    libjson-perl
    libcgi-application-perl
    libdbd-sqlite3-perl
    libcgi-session-perl
)

# Check each package availability before installing
for pkg in "${APT_PKGS[@]}"; do
    if apt-cache policy "$pkg" | grep -q "Version table"; then
        echo "  ✓ $pkg is available"
    else
        echo "  ✗ $pkg is NOT available in Ubuntu 24.04"
        # Remove from array
        APT_PKGS=("${APT_PKGS[@]/$pkg}")
    fi
done

# Install available packages
if [ ${#APT_PKGS[@]} -gt 0 ]; then
    sudo apt-get install -y "${APT_PKGS[@]}"
fi

# Install cpanminus if not present
if ! command -v cpanm >/dev/null 2>&1; then
    echo "Installing cpanminus..."
    sudo apt-get install -y cpanminus || sudo cpan App::cpanminus
fi

# Install modules not in Ubuntu 24.04 via CPAN
echo "Installing CPAN-only modules..."
CPAN_MODULES=(
    Text::NSP
    # Add other modules here if they fail to install via apt
)

for module in "${CPAN_MODULES[@]}"; do
    echo "  Installing $module via CPAN..."
    sudo cpanm --notest "$module" || echo "  Warning: Failed to install $module"
done

# Fallback: Try installing any remaining missing modules via CPAN
echo "Checking for any missing modules and installing via CPAN fallback..."
FALLBACK_MODULES=(
    CGI::Application
    YAML::XS
    DBD::SQLite
    XML::LibXML
    XML::Parser
    JSON
    Spreadsheet::WriteExcel
)

for module in "${FALLBACK_MODULES[@]}"; do
    if ! perl -M"$module" -e '1' 2>/dev/null; then
        echo "  Installing $module via CPAN fallback..."
        sudo cpanm --notest "$module" || echo "  Warning: Failed to install $module via CPAN"
    fi
done

echo ""
echo "Verifying installed packages:"
echo ""
echo "System packages (apt):"
for pkg in libyaml-perl libyaml-libyaml-perl libxml-libxml-perl libxml-parser-perl \
         libspreadsheet-writeexcel-perl libjson-perl libcgi-application-perl \
         libdbd-sqlite3-perl libcgi-session-perl; do
    if dpkg -l | grep -q "^ii\s\+$pkg\s"; then
        echo "  ✓ $pkg is installed"
    else
        echo "  ✗ $pkg is NOT installed"
    fi
done

echo ""
echo "CPAN modules:"
for module in "Text::NSP" "YAML::XS" "DBD::SQLite" "CGI::Application" "XML::LibXML" \
              "XML::Parser" "JSON" "Spreadsheet::WriteExcel"; do
    if perl -M"$module" -e 'print \"✓ $module is installed\n\"' 2>/dev/null; then
        :
    else
        echo "  ✗ $module is NOT installed"
    fi
done

echo ""
echo "Installation completed!"
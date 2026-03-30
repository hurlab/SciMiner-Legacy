#!/bin/bash
# SciMiner Perl Modules Installation Script
# This script installs all required Perl modules for SciMiner

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCIMINER_HOME="${SCIMINER_HOME:-/home/sciminer}"

print_success "SciMiner Perl Modules Installation"
echo "======================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script needs to be run with sudo privileges"
    exit 1
fi

# Verify infrastructure is already set up
print_status "Verifying infrastructure is set up..."

# Check Apache
if ! systemctl is-active --quiet apache2; then
    print_error "Apache2 is not running. Please run SETUP_INFRASTRUCTURE.sh first"
    exit 1
fi

# Check MariaDB
if ! systemctl is-active --quiet mariadb && ! systemctl is-active --quiet mysql; then
    print_error "Database is not running. Please run SETUP_INFRASTRUCTURE.sh first"
    exit 1
fi

# Check SciMiner directory
if [ ! -d "$SCIMINER_HOME" ]; then
    print_error "SciMiner directory not found: $SCIMINER_HOME"
    exit 1
fi

print_success "Infrastructure verification passed"
echo ""

# Stage 1: Install Build Tools and Development Headers
echo "==================================="
echo "Stage 1: Build Tools and Headers"
echo "==================================="

print_status "Updating package lists..."
apt-get update

print_status "Installing build tools..."
apt-get install -y \
    build-essential \
    gcc \
    make \
    pkg-config \
    libc6-dev

print_status "Installing development headers..."
apt-get install -y \
    libxml2-dev \
    libyaml-dev \
    zlib1g-dev \
    libmysqlclient-dev

print_success "Build tools and headers installed"

# Stage 2: Install System Perl Packages
echo ""
echo "==================================="
echo "Stage 2: System Perl Packages"
echo "==================================="

print_status "Installing Perl packages from Ubuntu repositories..."

# Core packages that are available in Ubuntu 24.04
APT_PACKAGES=(
    libdbi-perl
    libdbd-mysql-perl
    libdbd-sqlite3-perl
    libcgi-pm-perl
    libyaml-perl
    libyaml-libyaml-perl
    libxml-libxml-perl
    libxml-parser-perl
    libjson-perl
    libjson-xs-perl
    libhtml-template-perl
    libwww-perl
    liburi-perl
    libcgi-session-perl
    libunicode-string-perl
)

# Install packages with error handling
for package in "${APT_PACKAGES[@]}"; do
    if apt-cache show "$package" &> /dev/null; then
        print_status "  Installing $package..."
        apt-get install -y "$package" || print_warning "  Failed to install $package"
    else
        print_warning "  Package $package not available in Ubuntu 24.04"
    fi
done

# Try optional packages
print_status "Installing optional packages..."
apt-get install -y \
    libspreadsheet-writeexcel-perl \
    libcgi-application-perl \
    libtext-nsp-perl || echo "  Some optional packages not available, will install via CPAN"

print_success "System packages installation complete"

# Stage 3: Install cpanminus for CPAN Modules
echo ""
echo "==================================="
echo "Stage 3: CPAN Setup"
echo "==================================="

if ! command -v cpanm >/dev/null 2>&1; then
    print_status "Installing cpanminus..."
    apt-get install -y cpanminus || cpan App::cpanminus
else
    print_status "cpanminus already installed"
fi

print_success "CPAN setup complete"

# Stage 4: Install CPAN Modules
echo ""
echo "==================================="
echo "Stage 4: CPAN Modules"
echo "==================================="

print_status "Installing required Perl modules via CPAN..."

# List of modules to install via CPAN
CPAN_MODULES=(
    "Text::NSP"              # Not in Ubuntu 24.04
    "CGI::Application"       # Might not be available
    "Spreadsheet::WriteExcel" # Might not be available
    "Boulder::Medline"       # Custom module for Medline parsing
    "YAML::XS"              # Faster YAML (if system package fails)
    "Unicode::String"       # For Unicode string handling
    "LWP::UserAgent"        # For web requests
    "CGI::Debug"            # For CGI debugging in development
    "Crypt::Eksblowfish::Bcrypt"  # For secure password hashing
)

for module in "${CPAN_MODULES[@]}"; do
    if perl -M"$module" -e '1' 2>/dev/null; then
        print_status "  $module already installed"
    else
        print_status "  Installing $module via CPAN..."
        cpanm --notest "$module" || print_warning "  Failed to install $module"
    fi
done

# Fallback: Try installing any remaining missing modules
print_status "Installing any additional missing modules..."
FALLBACK_MODULES=(
    "CGI::Application"
    "Spreadsheet::WriteExcel"
    "DBD::SQLite"
    "XML::LibXML"
    "XML::Parser"
    "JSON"
)

for module in "${FALLBACK_MODULES[@]}"; do
    if ! perl -M"$module" -e '1' 2>/dev/null; then
        print_status "  Installing $module via CPAN fallback..."
        cpanm --notest "$module" || print_warning "  Failed to install $module via CPAN"
    fi
done

print_success "CPAN modules installation complete"

# Stage 5: Fix Known Module Issues
echo ""
echo "==================================="
echo "Stage 5: Fix Known Issues"
echo "==================================="

# Fix Boulder::Medline syntax errors if installed
MEDLINE_PATH="/usr/local/share/perl/5.38.2/Boulder/Medline.pm"
if [ -f "$MEDLINE_PATH" ]; then
    print_status "Fixing Boulder::Medline syntax errors..."

    # Create backup
    cp "$MEDLINE_PATH" "${MEDLINE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

    # Fix syntax issues
    sed -i 's/$line=@recordlines\[$i\];/$line=$recordlines[$i];/' "$MEDLINE_PATH"
    sed -i 's/for (\$i=/for (my $i=/' "$MEDLINE_PATH"
    sed -i '263a my($junk, $ui, $da, $pmid, $ad, $so);' "$MEDLINE_PATH"

    # Verify syntax
    if perl -c "$MEDLINE_PATH" 2>/dev/null; then
        print_success "  Boulder::Medline syntax fixed successfully"
    else
        print_warning "  Boulder::Medline may still have issues"
    fi
else
    print_status "Boulder::Medline not found, skipping syntax fix"
fi

# Stage 6: Update CGI Scripts
echo ""
echo "==================================="
echo "Stage 6: Update CGI Scripts"
echo "==================================="

print_status "Updating CGI scripts to use system Perl..."

# Find and update all CGI scripts to use system Perl
CGI_SCRIPTS=$(find $SCIMINER_HOME/web/html -name "*.cgi" -type f 2>/dev/null)

if [ -n "$CGI_SCRIPTS" ]; then
    for script in $CGI_SCRIPTS; do
        # Check if script uses conda Perl
        if grep -q "#!/home/sciminer/miniconda3" "$script" 2>/dev/null; then
            sed -i 's|#!/home/sciminer/miniconda3/envs/sciminer/bin/perl|#!/usr/bin/perl|g' "$script"
            chmod +x "$script"
        fi
    done
    print_success "CGI scripts updated"
else
    print_warning "No CGI scripts found to update"
fi

# Stage 7: Final Verification
echo ""
echo "==================================="
echo "Stage 7: Final Verification"
echo "==================================="

# Run the module check script
if [ -f "$SCIMINER_HOME/check_system_perl_modules.pl" ]; then
    print_status "Running Perl module verification..."
    /usr/bin/perl "$SCIMINER_HOME/check_system_perl_modules.pl"
else
    print_status "Module check script not found, creating temporary check..."

    # Create temporary check
    cat > /tmp/check_modules.pl << 'EOF'
#!/usr/bin/perl
my @modules = ('DBI', 'DBD::mysql', 'CGI', 'CGI::Session', 'CGI::Application',
               'HTML::Template', 'YAML', 'YAML::XS', 'Text::NSP',
               'Spreadsheet::WriteExcel', 'Data::Dumper', 'Boulder::Medline',
               'DBD::SQLite', 'XML::LibXML', 'XML::Parser', 'JSON');
print "Checking installed modules:\n";
foreach my $module (@modules) {
    eval "use $module ();";
    if ($@) {
        print "  ❌ $module - Missing\n";
    } else {
        print "  ✅ $module - Installed\n";
    }
}
EOF
    /usr/bin/perl /tmp/check_modules.pl
    rm /tmp/check_modules.pl
fi

# Test Apache CGI
print_status "Testing Apache CGI configuration..."
mkdir -p /tmp/test_cgi
cat > /tmp/test_cgi/test.cgi << 'EOF'
#!/usr/bin/perl
print "Content-Type: text/plain\n\n";
print "CGI is working with system Perl!\n";
print "Perl version: $]\n";
EOF
chmod +x /tmp/test_cgi/test.cgi

if curl -s http://localhost:8888/test.cgi 2>/dev/null | grep -q "working"; then
    print_success "Apache CGI is working correctly"
else
    print_warning "Apache CGI test failed - check configuration"
fi
rm -rf /tmp/test_cgi

# Final status
echo ""
echo "==================================="
print_success "Perl Modules Installation Complete!"
echo "==================================="
echo ""
echo "Next Steps:"
echo "  1. Test SciMiner: curl http://localhost:8888/SciMiner/"
echo "  2. Check logs if issues: tail -f /var/log/apache2/sciminer_error.log"
echo "  3. Verify all SciMiner features are working"
echo ""
echo "Module Installation Summary:"
echo "  System packages: ${#APT_PACKAGES[@]} attempted"
echo "  CPAN modules: ${#CPAN_MODULES[@]} attempted"
echo "  Syntax fixes: Applied to Boulder::Medline if present"
echo ""
echo "If some modules are missing, run:"
echo "  sudo cpanm Module::Name"
echo ""
echo "For module locations, see: $SCIMINER_HOME/PERL_MODULE_LOCATIONS.md"
#!/bin/bash
# Complete SciMiner Installation Script for Ubuntu 24.04
# This script installs all dependencies and fixes known issues

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
WEB_PORT="${WEB_PORT:-8888}"
DB_NAME="${DB_NAME:-sciminer}"
DB_USER="${DB_USER:-sciminer}"
DB_PASS="${DB_PASS:-124356!@}"

print_success "Starting complete SciMiner installation..."
echo "========================================"

# 1. System Update and Basic Tools
print_status "Step 1/7: Installing system updates and basic tools..."
apt-get update
apt-get install -y \
    build-essential \
    gcc \
    make \
    pkg-config \
    libc6-dev \
    wget \
    curl \
    unzip

# 2. Development Headers
print_status "Step 2/7: Installing development headers..."
apt-get install -y \
    libxml2-dev \
    libyaml-dev \
    zlib1g-dev \
    libmysqlclient-dev

# 3. Web Server and Database
print_status "Step 3/7: Installing Apache web server and MariaDB..."
apt-get install -y \
    apache2 \
    mariadb-server \
    mariadb-client

# 4. Core System Perl Packages
print_status "Step 4/7: Installing core Perl packages from Ubuntu repositories..."
apt-get install -y \
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

# Optional packages that might not be available
apt-get install -y \
    libspreadsheet-writeexcel-perl \
    libcgi-application-perl \
    libtext-nsp-perl || echo "Some optional packages not available in Ubuntu 24.04, will install via CPAN"

# 5. Install cpanminus for CPAN modules
print_status "Step 5/7: Installing CPAN modules..."
if ! command -v cpanm >/dev/null 2>&1; then
    apt-get install -y cpanminus || cpan App::cpanminus
fi

# Install required CPAN modules
print_status "Installing Perl modules via CPAN..."
CPAN_MODULES=(
    "Text::NSP"
    "CGI::Application"
    "Spreadsheet::WriteExcel"
    "Boulder::Medline"
    "YAML::XS"
    "DBD::SQLite"
)

for module in "${CPAN_MODULES[@]}"; do
    if ! perl -M"$module" -e '1' 2>/dev/null; then
        print_status "  Installing $module via CPAN..."
        cpanm --notest "$module" || print_warning "  Failed to install $module"
    else
        print_status "  $module already installed"
    fi
done

# 6. Fix Boulder::Medline syntax errors
print_status "Step 6/7: Fixing known issues in installed modules..."

# Fix Boulder::Medline if installed
MEDLINE_PATH="/usr/local/share/perl/5.38.2/Boulder/Medline.pm"
if [ -f "$MEDLINE_PATH" ]; then
    print_status "Fixing Boulder::Medline syntax errors..."

    # Backup original file
    cp "$MEDLINE_PATH" "${MEDLINE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

    # Fix array access syntax
    sed -i 's/$line=@recordlines\[$i\];/$line=$recordlines[$i];/' "$MEDLINE_PATH"

    # Add missing 'my' for $i
    sed -i 's/for (\$i=/for (my $i=/' "$MEDLINE_PATH"

    # Add missing variable declarations
    sed -i '263a my($junk, $ui, $da, $pmid, $ad, $so);' "$MEDLINE_PATH"

    # Verify syntax
    if perl -c "$MEDLINE_PATH" 2>/dev/null; then
        print_success "  Boulder::Medline syntax fixed successfully"
    else
        print_warning "  Boulder::Medline still has syntax issues"
    fi
fi

# 7. Configure Apache for SciMiner
print_status "Step 7/7: Configuring Apache web server..."

# Create Apache configuration
cat > /etc/apache2/sites-available/sciminer.conf << EOF
<VirtualHost *:$WEB_PORT>
    ServerName localhost
    ServerAdmin sciminer@localhost

    # Document root for SciMiner
    DocumentRoot $SCIMINER_HOME/web/html

    # Directory configuration
    <Directory $SCIMINER_HOME/web/html>
        Options Indexes FollowSymLinks ExecCGI
        AllowOverride None
        Require all granted
    </Directory>

    # Enable CGI for .cgi files in SciMiner directory
    <Directory "$SCIMINER_HOME/web/html/SciMiner">
        Options +ExecCGI
        AddHandler cgi-script .cgi .pl
        Require all granted
    </Directory>

    # DirectoryIndex - serve index.html by default
    DirectoryIndex index.html index.htm

    # Error and access logs
    ErrorLog \${APACHE_LOG_DIR}/sciminer_error.log
    CustomLog \${APACHE_LOG_DIR}/sciminer_access.log combined

    # Set environment variables for SciMiner
    SetEnv PERL5LIB $SCIMINER_HOME/ANNOTATION/SciMinerDB/Modules

    # Increase timeout for long-running scripts
    <IfModule mod_reqtimeout.c>
        RequestReadTimeout header=20-40,MinRate=500 body=10,MinRate=500
    </IfModule>
</VirtualHost>
EOF

# Enable required Apache modules
a2enmod cgi
a2enmod rewrite

# Enable the site
a2ensite sciminer.conf

# Listen on the specified port
if ! grep -q "Listen $WEB_PORT" /etc/apache2/ports.conf; then
    echo "Listen $WEB_PORT" >> /etc/apache2/ports.conf
fi

# Set proper permissions
chown -R sciminer:sciminer $SCIMINER_HOME/web 2>/dev/null || chown -R $(stat -c "%U:%G" $SCIMINER_HOME) $SCIMINER_HOME/web
find $SCIMINER_HOME/web/html -name "*.cgi" -exec chmod +x {} \; 2>/dev/null || true

# Restart Apache
systemctl restart apache2

# Configure Database if needed
print_status "Configuring MariaDB database..."
systemctl start mariadb
systemctl enable mariadb

# Create database and user if they don't exist
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import schema if available
if [ -f "$SCIMINER_HOME/sciminer.sql" ]; then
    print_status "Importing database schema..."
    mysql -u $DB_USER -p$DB_PASS $DB_NAME < "$SCIMINER_HOME/sciminer.sql"
fi

# Update SciMiner configuration
if [ -f "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini" ]; then
    print_status "Updating SciMiner configuration..."
    sed -i "s|^SciMinerServerURL=.*|SciMinerServerURL=http://localhost:$WEB_PORT/|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
    sed -i "s|^DB=.*|DB=$DB_NAME|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
    sed -i "s|^username=.*|username=$DB_USER|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
    sed -i "s|^password=.*|password=$DB_PASS|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
fi

# Final verification
echo ""
echo "========================================"
print_success "Installation completed!"
echo ""
echo "Running final verification..."
echo "========================================"

# Run the test script
if [ -f "$SCIMINER_HOME/check_system_perl_modules.pl" ]; then
    /usr/bin/perl "$SCIMINER_HOME/check_system_perl_modules.pl"
fi

echo ""
echo "========================================"
print_success "SciMiner Installation Complete!"
echo ""
echo "Access Information:"
echo "  Web Interface: http://localhost:$WEB_PORT/SciMiner/"
echo "  Database: $DB_NAME"
echo "  Database User: $DB_USER"
echo ""
echo "Important Notes:"
echo "  1. The database password '$DB_PASS' should be changed for production"
echo "  2. Configure firewall to allow port $WEB_PORT if needed"
echo "  3. Check logs at /var/log/apache2/sciminer_error.log for issues"
echo ""
echo "To test SciMiner functionality:"
echo "  curl http://localhost:$WEB_PORT/SciMiner/"
echo ""
echo "For troubleshooting:"
echo "  tail -f /var/log/apache2/sciminer_error.log"
echo "========================================"
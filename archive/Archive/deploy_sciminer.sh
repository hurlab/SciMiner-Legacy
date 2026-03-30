#!/bin/bash
# SciMiner System Deployment Script
# This script deploys SciMiner using system Perl and packages

set -e  # Exit on any error

# Configuration
SCIMINER_HOME="${SCIMINER_HOME:-/home/sciminer}"
SCIMINER_USER="${SCIMINER_USER:-sciminer}"
WEB_PORT="${WEB_PORT:-8888}"
DB_NAME="${DB_NAME:-sciminer}"
DB_USER="${DB_USER:-sciminer}"
DB_PASS="${DB_PASS:-124356!@}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script needs to be run with sudo privileges"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."

    # Check if Ubuntu/Debian
    if ! command -v apt-get &> /dev/null; then
        print_error "This script is designed for Ubuntu/Debian systems"
        exit 1
    fi

    # Check if web server port is available
    if netstat -tuln | grep -q ":$WEB_PORT "; then
        print_warning "Port $WEB_PORT is already in use"
    fi

    print_status "System requirements check completed"
}

# Install system packages
install_packages() {
    print_status "Installing system packages..."

    # Update package lists
    apt-get update

    # Install build tools first
    print_status "Installing build tools and development headers..."
    apt-get install -y build-essential gcc make libc6-dev libyaml-dev libxml2-dev

    # Install available system packages
    if [[ -f "$SCIMINER_HOME/requirements.ubuntu" ]]; then
        # Read packages from file, filter out comments and Text::NSP (not in Ubuntu 24.04)
        packages=$(grep -v '^#' "$SCIMINER_HOME/requirements.ubuntu" | grep -v '^$' | grep -v 'libtext-nsp-perl' | tr '\n' ' ')

        # Check each package before installing
        print_status "Checking package availability..."
        available_packages=""
        for pkg in $packages; do
            if apt-cache policy "$pkg" | grep -q "Version table"; then
                available_packages="$available_packages $pkg"
            else
                print_warning "Package $pkg not available in Ubuntu 24.04, will skip"
            fi
        done

        if [[ -n "$available_packages" ]]; then
            apt-get install -y $available_packages
        fi
    else
        print_error "Requirements file not found: $SCIMINER_HOME/requirements.ubuntu"
        exit 1
    fi

    # Install modules not in Ubuntu 24.04 via CPAN
    print_status "Installing CPAN-only modules..."

    # Install cpanminus if not present
    if ! command -v cpanm &> /dev/null; then
        apt-get install -y cpanminus || cpan App::cpanminus
    fi

    # Install Text::NSP and other missing modules
    for module in "Text::NSP" "YAML::XS" "Boulder::Medline"; do
        if ! perl -M"$module" -e '1' 2>/dev/null; then
            print_status "Installing $module via CPAN..."
            cpanm --notest "$module" || print_warning "Failed to install $module"
        fi
    done

    print_status "System packages installed successfully"
}

# Setup database
setup_database() {
    print_status "Setting up database..."

    # Start MariaDB/MySQL service
    if command -v mariadb &> /dev/null; then
        systemctl start mariadb
        systemctl enable mariadb
    else
        systemctl start mysql
        systemctl enable mysql
    fi

    # Create database and user if they don't exist
    mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    # Import schema if available
    if [[ -f "$SCIMINER_HOME/sciminer.sql" ]]; then
        mysql -u $DB_USER -p$DB_PASS $DB_NAME < "$SCIMINER_HOME/sciminer.sql"
        print_status "Database schema imported"
    fi

    print_status "Database setup completed"
}

# Setup web server
setup_webserver() {
    print_status "Setting up Apache web server..."

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

    # Enable required modules
    a2enmod cgi
    a2enmod rewrite

    # Enable the site
    a2ensite sciminer.conf

    # Listen on the specified port
    if ! grep -q "Listen $WEB_PORT" /etc/apache2/ports.conf; then
        echo "Listen $WEB_PORT" >> /etc/apache2/ports.conf
    fi

    # Set proper permissions
    chown -R $SCIMINER_USER:$SCIMINER_USER $SCIMINER_HOME/web
    find $SCIMINER_HOME/web/html -name "*.cgi" -exec chmod +x {} \;

    # Restart Apache
    systemctl restart apache2

    print_status "Apache web server configured on port $WEB_PORT"
}

# Update SciMiner configuration
update_config() {
    print_status "Updating SciMiner configuration..."

    # Update annotationENV.ini
    if [[ -f "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini" ]]; then
        sed -i "s|^SciMinerServerURL=.*|SciMinerServerURL=http://localhost:$WEB_PORT/|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
        sed -i "s|^DB=.*|DB=$DB_NAME|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
        sed -i "s|^username=.*|username=$DB_USER|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
        sed -i "s|^password=.*|password=$DB_PASS|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
        print_status "Configuration updated"
    else
        print_warning "Configuration file not found, please update manually"
    fi
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."

    # Check if Apache is running
    if systemctl is-active --quiet apache2; then
        print_status "Apache is running"
    else
        print_error "Apache is not running"
    fi

    # Check if database is accessible
    if mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME;" &> /dev/null; then
        print_status "Database connection successful"
    else
        print_error "Database connection failed"
    fi

    # Test web interface
    if curl -s http://localhost:$WEB_PORT/SciMiner/ | grep -q "HTML"; then
        print_status "Web interface is accessible"
    else
        print_warning "Web interface test failed, please check manually"
    fi
}

# Print completion message
print_completion() {
    print_status "SciMiner deployment completed successfully!"
    echo
    echo "Access Information:"
    echo "  Web Interface: http://localhost:$WEB_PORT/SciMiner/"
    echo "  Database: $DB_NAME"
    echo "  Database User: $DB_USER"
    echo
    echo "Important Notes:"
    echo "  1. Please change the default database password for production use"
    echo "  2. Configure firewall to allow port $WEB_PORT if needed"
    echo "  3. Review security configuration in $SCIMINER_HOME/PRODUCTION_SECURITY_CHECKLIST.md"
    echo "  4. Check logs at /var/log/apache2/sciminer_error.log for troubleshooting"
    echo
}

# Main deployment flow
main() {
    print_status "Starting SciMiner deployment..."

    check_root
    check_requirements
    install_packages
    setup_database
    setup_webserver
    update_config
    verify_installation
    print_completion

    print_status "Deployment completed successfully!"
}

# Run main function
main "$@"
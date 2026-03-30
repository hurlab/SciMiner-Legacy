#!/bin/bash

# SciMiner Automated Installation Script
# Version: 1.0
# Compatible with Ubuntu 20.04+ and Debian 10+

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
SCIMINER_USER="sciminer"
SCIMINER_HOME="/home/${SCIMINER_USER}"
DB_NAME="sciminer"
DB_USER="sciminer"
DB_PASS="sciminer123"  # Change this!
SERVER_PORT="8888"
SCIMINER_URL="http://localhost:${SERVER_PORT}"

# Logging
LOG_FILE="/tmp/sciminer_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

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
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root!"
        print_warning "Run as a regular user. Script will use sudo when needed."
        exit 1
    fi
}

# Check if user has sudo access
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -n "Enter sudo password: "
        read -s SUDO_PASS
        echo
        if ! echo "$SUDO_PASS" | sudo -S true 2>/dev/null; then
            print_error "Invalid sudo password!"
            exit 1
        fi
    fi
}

# System update
update_system() {
    print_status "Updating system packages..."
    echo "$SUDO_PASS" | sudo -S apt-get update
    echo "$SUDO_PASS" | sudo -S apt-get upgrade -y
}

# Install Apache
install_apache() {
    print_status "Installing Apache web server..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y apache2

    # Enable modules
    print_status "Enabling Apache modules..."
    echo "$SUDO_PASS" | sudo -S a2enmod cgi alias env reqtimeout cgid

    # Configure port
    print_status "Configuring Apache to listen on port $SERVER_PORT..."
    echo "Listen $SERVER_PORT" | echo "$SUDO_PASS" | sudo -S tee /etc/apache2/ports.conf > /dev/null
}

# Install MySQL
install_mysql() {
    print_status "Installing MySQL database server..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y mysql-server

    # Secure installation (non-interactive)
    print_status "Securing MySQL installation..."
    echo "$SUDO_PASS" | sudo -S mysql -e "DELETE FROM mysql.user WHERE User='';"
    echo "$SUDO_PASS" | sudo -S mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    echo "$SUDO_PASS" | sudo -S mysql -e "DROP DATABASE IF EXISTS test;"
    echo "$SUDO_PASS" | sudo -S mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    echo "$SUDO_PASS" | sudo -S mysql -e "FLUSH PRIVILEGES;"
}

# Install Perl dependencies
install_perl_deps() {
    print_status "Installing Perl and dependencies..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y perl perl-base build-essential cpanminus

    # System Perl modules
    print_status "Installing system Perl modules..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y \
        libdbi-perl libdbd-mysql-perl \
        libcgi-pm-perl libhtml-template-perl \
        libwww-perl liblwp-protocol-https-perl \
        libio-socket-ssl-perl libnet-ssleay-perl \
        libmailtools-perl libauthen-sasl-perl
}

# Setup database
setup_database() {
    print_status "Setting up SciMiner database..."

    # Create database and user
    echo "$SUDO_PASS" | sudo -S mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET latin1 COLLATE latin1_swedish_ci;"
    echo "$SUDO_PASS" | sudo -S mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    echo "$SUDO_PASS" | sudo -S mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    echo "$SUDO_PASS" | sudo -S mysql -e "FLUSH PRIVILEGES;"

    # Import database if dump file exists
    if [[ -f "$SCIMINER_HOME/sciminer.sql" ]]; then
        print_status "Importing SciMiner database schema..."
        mysql -u $DB_USER -p$DB_PASS $DB_NAME < "$SCIMINER_HOME/sciminer.sql"
    else
        print_warning "Database dump file not found at $SCIMINER_HOME/sciminer.sql"
        print_warning "You will need to import the database manually."
    fi
}

# Configure Apache
configure_apache() {
    print_status "Configuring Apache virtual host..."

    # Create virtual host config
    cat << EOF | echo "$SUDO_PASS" | sudo -S tee /etc/apache2/sites-available/sciminer.conf > /dev/null
<VirtualHost *:$SERVER_PORT>
    ServerName localhost
    ServerAdmin admin@localhost

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

    # DirectoryIndex
    DirectoryIndex index.html index.htm

    # Error and access logs
    ErrorLog \${APACHE_LOG_DIR}/sciminer_error.log
    CustomLog \${APACHE_LOG_DIR}/sciminer_access.log combined

    # Environment variables
    SetEnv PERL5LIB $SCIMINER_HOME/ANNOTATION/SciMinerDB/Modules
</VirtualHost>
EOF

    # Disable default site and enable SciMiner
    echo "$SUDO_PASS" | sudo -S a2dissite 000-default
    echo "$SUDO_PASS" | sudo -S a2ensite sciminer

    # Restart Apache
    print_status "Restarting Apache..."
    echo "$SUDO_PASS" | sudo -S systemctl restart apache2
}

# Install CPAN modules
install_cpan_modules() {
    print_status "Installing additional CPAN modules..."

    # List of modules to install
    modules=(
        "Text::NSP"
        "CGI::Session"
        "Statistics::ChisqIndep"
        "Statistics::Distributions"
        "HTML::Parser"
        "XML::Simple"
        "JSON"
        "Date::Calc"
        "URI::Escape"
        "MIME::Base64"
        "Digest::MD5"
        "Text::Wrap"
    )

    for module in "${modules[@]}"; do
        print_status "Installing $module..."
        echo "$SUDO_PASS" | sudo -S cpanm -f $module || print_warning "Failed to install $module"
    done
}

# Set file permissions
set_permissions() {
    print_status "Setting file permissions..."

    # Home directory
    chmod 755 $SCIMINER_HOME

    # Web directory
    chmod -R 755 $SCIMINER_HOME/web

    # CGI scripts
    find $SCIMINER_HOME/web/html -name "*.cgi" -exec chmod +x {} \;
    find $SCIMINER_HOME/web/html -name "*.pl" -exec chmod +x {} \;

    # Create temp directory
    echo "$SUDO_PASS" | sudo -S mkdir -p /tmp/SciMiner
    echo "$SUDO_PASS" | sudo -S chmod 777 /tmp/SciMiner
}

# Update configuration
update_config() {
    print_status "Updating SciMiner configuration..."

    # Backup original config
    if [[ -f "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini" ]]; then
        cp "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini.backup"
    fi

    # Update config file
    sed -i "s|SciMinerServerURL=.*|SciMinerServerURL=$SCIMINER_URL/|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
    sed -i "s|password=.*|password=$DB_PASS|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
    sed -i "s|AdminEmail=.*|AdminEmail=admin@localhost|g" "$SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
}

# Create test script
create_test_script() {
    print_status "Creating test CGI script..."

    cat << 'EOF' > $SCIMINER_HOME/web/html/SciMiner/test_installation.cgi
#!/usr/bin/perl

print "Content-Type: text/plain\n\n";
print "SciMiner Installation Test\n";
print "=========================\n\n";

print "Perl Version: $]\n";
print "Script Location: $0\n";

# Test database connection
use DBI;
my $dsn = "DBI:mysql:database=sciminer;host=localhost";
my $user = "sciminer";
my $pass = "sciminer123";

eval {
    my $dbh = DBI->connect($dsn, $user, $pass);
    if ($dbh) {
        print "\nSUCCESS: Database connection established\n";
        my $sth = $dbh->prepare("SHOW TABLES");
        $sth->execute();
        my $tables = $sth->rows();
        print "Database contains $tables tables\n";
        $dbh->disconnect();
    }
};
if ($@) {
    print "\nERROR: Database connection failed: $@\n";
    print "Check database configuration and password\n";
}

# Test module loading
BEGIN {
    push (@INC, "/home/sciminer/ANNOTATION/SciMinerDB/Modules/");
}

eval {
    require Annotation::basicIO;
    print "\nSUCCESS: Annotation::basicIO module loaded\n";
};
if ($@) {
    print "\nWARNING: Annotation::basicIO not loaded: $@\n";
}

print "\nInstallation test complete!\n";
EOF

    chmod +x $SCIMINER_HOME/web/html/SciMiner/test_installation.cgi
}

# Test installation
test_installation() {
    print_status "Testing SciMiner installation..."

    # Check Apache is running
    if systemctl is-active --quiet apache2; then
        print_status "Apache is running"
    else
        print_error "Apache is not running!"
        return 1
    fi

    # Check if port is listening
    if netstat -tuln 2>/dev/null | grep -q ":$SERVER_PORT "; then
        print_status "Apache is listening on port $SERVER_PORT"
    else
        print_error "Apache is not listening on port $SERVER_PORT!"
        return 1
    fi

    # Test web access
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$SERVER_PORT/SciMiner/ | grep -q "200"; then
        print_status "SciMiner main page is accessible"
    else
        print_warning "SciMiner main page may not be accessible"
    fi

    # Test CGI
    if curl -s http://localhost:$SERVER_PORT/SciMiner/test_installation.cgi | grep -q "SciMiner Installation Test"; then
        print_status "CGI scripts are working"
    else
        print_warning "CGI scripts may not be working properly"
    fi
}

# Print final instructions
print_instructions() {
    echo
    print_status "Installation completed!"
    echo
    echo "SciMiner URL: $SCIMINER_URL/SciMiner/"
    echo "Test Script: $SCIMINER_URL/SciMiner/test_installation.cgi"
    echo
    echo "Database Details:"
    echo "  - Database Name: $DB_NAME"
    echo "  - Database User: $DB_USER"
    echo "  - Database Password: $DB_PASS"
    echo
    echo "Log Files:"
    echo "  - Apache Error: /var/log/apache2/sciminer_error.log"
    echo "  - Apache Access: /var/log/apache2/sciminer_access.log"
    echo "  - Install Log: $LOG_FILE"
    echo
    print_warning "IMPORTANT: Change the default database password!"
    print_warning "Update $SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini if you change it."
    echo
    echo "Next Steps:"
    echo "1. Open $SCIMINER_URL/SciMiner/ in your browser"
    echo "2. Run the test script to verify installation"
    echo "3. Check logs if you encounter issues"
    echo "4. Read $SCIMINER_HOME/SETUP_GUIDE.md for detailed configuration"
}

# Main installation flow
main() {
    print_status "Starting SciMiner installation..."
    print_status "Log file: $LOG_FILE"

    check_root
    check_sudo
    update_system
    install_apache
    install_mysql
    install_perl_deps
    setup_database
    configure_apache
    install_cpan_modules
    set_permissions
    update_config
    create_test_script
    test_installation
    print_instructions

    print_status "Installation complete!"
}

# Run main function
main "$@"
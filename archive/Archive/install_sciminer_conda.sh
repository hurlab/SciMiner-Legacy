#!/bin/bash

# SciMiner Conda Environment Installation Script
# Version: 1.0
# For Ubuntu/Debian with Conda environment

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SCIMINER_USER="sciminer"
SCIMINER_HOME="/home/${SCIMINER_USER}"
CONDA_ENV="sciminer"
CONDA_PREFIX="${CONDA_PREFIX:-$HOME/miniconda3}"
SCIMINER_ENV_PATH="$CONDA_PREFIX/envs/$CONDA_ENV"
DB_NAME="sciminer"
DB_USER="sciminer"
DB_PASS="sciminer123"  # Change this!
SERVER_PORT="8888"
SCIMINER_URL="http://localhost:${SERVER_PORT}"

# Logging
LOG_FILE="/tmp/sciminer_conda_install_$(date +%Y%m%d_%H%M%S).log"
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

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as correct user
check_user() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root!"
        print_error "Run as the $SCIMINER_USER user."
        exit 1
    fi

    if [[ $USER != "$SCIMINER_USER" ]]; then
        print_warning "You are running as $USER, not $SCIMINER_USER"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check sudo access
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -n "Enter sudo password for Apache/MySQL installation: "
        read -s SUDO_PASS
        echo
        if ! echo "$SUDO_PASS" | sudo -S true 2>/dev/null; then
            print_error "Invalid sudo password!"
            exit 1
        fi
    fi
}

# Initialize conda
init_conda() {
    print_status "Initializing Conda..."

    # Source conda
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
    elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
        source "$HOME/anaconda3/etc/profile.d/conda.sh"
    else
        print_error "Conda not found! Please install Miniconda or Anaconda first."
        exit 1
    fi
}

# Create or activate conda environment
setup_conda_env() {
    print_status "Setting up SciMiner conda environment..."

    # Create environment if it doesn't exist
    if ! conda env list | grep -q "$CONDA_ENV"; then
        print_status "Creating new conda environment: $CONDA_ENV"
        conda create -n "$CONDA_ENV" perl=5.40 -y
    else
        print_status "Conda environment $CONDA_ENV already exists"
    fi

    # Activate environment
    conda activate "$CONDA_ENV"

    # Verify activation
    if [[ "$CONDA_DEFAULT_ENV" != "$CONDA_ENV" ]]; then
        print_error "Failed to activate conda environment"
        exit 1
    fi

    print_status "Activated conda environment: $CONDA_ENV"
}

# Install conda packages
install_conda_packages() {
    print_status "Installing conda packages..."

    # Install compilers and build tools
    conda install -y make gcc_linux-64 gxx_linux-64
    conda install -y libxml2 libxslt expat
    conda install -y openssl zlib bzip2 readline sqlite xz

    # Install cpanm if not present
    if ! command -v cpanm &> /dev/null; then
        print_status "Installing cpanm..."
        curl -L https://cpanmin.us | perl - App::cpanminus
    fi
}

# Install Perl modules
install_perl_modules() {
    print_status "Installing required Perl modules..."

    # IMPORTANT: Install database dependencies first from conda-forge
    print_status "Installing database dependencies from conda-forge..."
    conda install -c conda-forge libxcrypt -y
    conda install -c conda-forge perl-dbd-mysql -y
    conda install -c conda-forge perl-dbd-sqlite -y

    # Install DBI with force flag (required after conda-forge packages)
    print_status "Installing DBI with force flag..."
    cpanm -i DBI --force || print_warning "DBI installation failed"

    # Install other modules that typically work
    local modules=(
        "YAML"
        "YAML::XS"
        "Spreadsheet::WriteExcel"
        "Data::Dumper"
        "Test::More"
        "ExtUtils::MakeMaker"
    )

    for module in "${modules[@]}"; do
        print_status "Installing $module..."
        cpanm -i "$module" || print_warning "Failed to install $module"
    done

    # Install XML modules
    print_status "Installing XML modules..."
    cpanm -i XML::LibXML || print_warning "XML::LibXML installation failed"

    # Install Text::NSP
    cpanm -i Text::NSP || print_warning "Text::NSP installation failed"

    # Install CGI-related modules
    print_status "Installing CGI modules..."
    cpanm -i CGI CGI::Session HTML::Template || print_warning "Some CGI modules failed"

    # Try system packages as fallback for failing modules
    print_status "Installing remaining modules via system packages..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y libcgi-pm-perl libhtml-template-perl 2>/dev/null || true
}

# Install system dependencies (requires sudo)
install_system_deps() {
    print_header "Installing System Dependencies"

    # Update system
    print_status "Updating system packages..."
    echo "$SUDO_PASS" | sudo -S apt-get update

    # Install Apache
    print_status "Installing Apache web server..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y apache2

    # Install MySQL
    print_status "Installing MySQL database..."
    echo "$SUDO_PASS" | sudo -S apt-get install -y mysql-server

    # Enable Apache modules
    print_status "Enabling Apache modules..."
    echo "$SUDO_PASS" | sudo -S a2enmod cgi cgid alias env
}

# Setup database
setup_database() {
    print_status "Setting up SciMiner database..."

    # Create database and user
    echo "$SUDO_PASS" | sudo -S mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET latin1 COLLATE latin1_swedish_ci;" 2>/dev/null || true
    echo "$SUDO_PASS" | sudo -S mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" 2>/dev/null || true
    echo "$SUDO_PASS" | sudo -S mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" 2>/dev/null || true
    echo "$SUDO_PASS" | sudo -S mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

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
    print_status "Configuring Apache for conda environment..."

    # Create virtual host config
    cat << EOF | echo "$SUDO_PASS" | sudo -S tee /etc/apache2/sites-available/sciminer.conf > /dev/null
<VirtualHost *:$SERVER_PORT>
    ServerName localhost
    ServerAdmin admin@localhost

    # Document root for SciMiner
    DocumentRoot $SCIMINER_HOME/web/html

    # Use Conda Perl environment
    PerlSwitches -I$SCIMINER_ENV_PATH/lib/perl5/site_perl
    SetEnv PERL5LIB $SCIMINER_ENV_PATH/lib/perl5/site_perl
    SetEnv PATH $SCIMINER_ENV_PATH/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    SetEnv PERL_BADLANG 0

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

    # Additional environment for SciMiner
    SetEnv PERL5LIB $SCIMINER_HOME/ANNOTATION/SciMinerDB/Modules:$SCIMINER_ENV_PATH/lib/perl5/site_perl
</VirtualHost>
EOF

    # Configure port
    echo "Listen $SERVER_PORT" | echo "$SUDO_PASS" | sudo -S tee /etc/apache2/ports.conf > /dev/null

    # Enable site
    echo "$SUDO_PASS" | sudo -S a2dissite 000-default 2>/dev/null || true
    echo "$SUDO_PASS" | sudo -S a2ensite sciminer

    # Restart Apache
    print_status "Restarting Apache..."
    echo "$SUDO_PASS" | sudo -S systemctl restart apache2
}

# Update shebang lines
update_shebang() {
    print_status "Updating shebang lines in Perl scripts..."

    find "$SCIMINER_HOME/web/html" -name "*.cgi" -type f | while read file; do
        sed -i "1s|#!.*|#!$SCIMINER_ENV_PATH/bin/perl|" "$file"
    done

    find "$SCIMINER_HOME/web/html" -name "*.pl" -type f | while read file; do
        sed -i "1s|#!.*|#!$SCIMINER_ENV_PATH/bin/perl|" "$file"
    done
}

# Set file permissions
set_permissions() {
    print_status "Setting file permissions..."

    # Home directory
    chmod 755 "$SCIMINER_HOME"

    # Web directory
    chmod -R 755 "$SCIMINER_HOME/web"

    # CGI scripts
    find "$SCIMINER_HOME/web/html" -name "*.cgi" -exec chmod +x {} \;
    find "$SCIMINER_HOME/web/html" -name "*.pl" -exec chmod +x {} \;

    # Create temp directory
    echo "$SUDO_PASS" | sudo -S mkdir -p /tmp/SciMiner
    echo "$SUDO_PASS" | sudo -S chmod 777 /tmp/SciMiner
}

# Create mock Boulder module
create_boulder_mock() {
    print_status "Creating mock Boulder::Medline module..."

    mkdir -p "$SCIMINER_ENV_PATH/lib/perl5/site_perl/Boulder"

    cat << 'EOF' > "$SCIMINER_ENV_PATH/lib/perl5/site_perl/Boulder/Medline.pm"
package Boulder::Medline;

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub parse_record {
    my ($self, $record) = @_;
    # Basic parsing logic for Medline format
    my %data;

    # Split by lines and process
    my @lines = split /\n/, $record;
    foreach my $line (@lines) {
        if ($line =~ /^(\w{2,4})\s*-\s*(.*)$/) {
            my ($field, $value) = ($1, $2);
            $data{$field} = $value;
        }
    }

    return \%data;
}

sub get {
    my ($self, $field) = @_;
    return $self->{$field} || '';
}

1;
EOF

    print_status "Boulder::Medline mock module created"
}

# Create test script
create_test_script() {
    print_status "Creating test CGI script..."

    cat << EOF > "$SCIMINER_HOME/web/html/SciMiner/test_conda_install.cgi"
#!/usr/bin/env perl

print "Content-Type: text/plain\n\n";
print "SciMiner Conda Installation Test\n";
print "=================================\n\n";

print "Perl Version: $]\n";
print "Perl Path: \$^X\n";
print "Conda Environment: \$ENV{CONDA_DEFAULT_ENV}\n\n";

# Test key modules
my @modules = qw(
    DBI
    DBD::MySQL
    YAML
    Text::NSP
    Boulder::Medline
    Spreadsheet::WriteExcel
    XML::LibXML
    Data::Dumper
);

print "Testing Modules:\n";
print "---------------\n";
foreach my \$module (@modules) {
    eval "use \$module";
    if (\$@) {
        print "FAIL: \$module - \$@\n";
    } else {
        print "OK: \$module\n";
    }
}

# Test database connection
print "\nTesting Database Connection:\n";
print "----------------------------\n";
use DBI;
my \$dsn = "DBI:mysql:database=$DB_NAME;host=localhost";
eval {
    my \$dbh = DBI->connect(\$dsn, '$DB_USER', '$DB_PASS');
    if (\$dbh) {
        print "OK: Database connection successful\n";

        # Test if tables exist
        my \$sth = \$dbh->prepare("SHOW TABLES");
        \$sth->execute();
        my \$tables = \$sth->rows();
        print "INFO: Database contains \$tables tables\n";

        \$dbh->disconnect();
    }
};
if (\$@) {
    print "FAIL: Database connection - \$@\n";
}

print "\nEnvironment Variables:\n";
print "----------------------\n";
print "PERL5LIB: \$ENV{PERL5LIB}\n";
print "PATH: \$ENV{PATH}\n";

print "\nInstallation test complete!\n";
EOF

    chmod +x "$SCIMINER_HOME/web/html/SciMiner/test_conda_install.cgi"
}

# Test installation
test_installation() {
    print_status "Testing installation..."

    # Check Apache is running
    if echo "$SUDO_PASS" | sudo -S systemctl is-active --quiet apache2; then
        print_status "Apache is running"
    else
        print_error "Apache is not running!"
        return 1
    fi

    # Check conda environment
    if [[ "$CONDA_DEFAULT_ENV" == "$CONDA_ENV" ]]; then
        print_status "Conda environment is active"
    else
        print_error "Conda environment is not active!"
        return 1
    fi

    # Test web access
    sleep 2  # Give Apache time to start
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$SERVER_PORT/SciMiner/ | grep -q "200"; then
        print_status "SciMiner main page is accessible"
    else
        print_warning "SciMiner main page may not be accessible"
    fi

    # Test CGI
    if curl -s http://localhost:$SERVER_PORT/SciMiner/test_conda_install.cgi | grep -q "SciMiner Conda Installation Test"; then
        print_status "CGI scripts are working"
    else
        print_warning "CGI scripts may not be working properly"
    fi
}

# Print final instructions
print_instructions() {
    echo
    print_header "Installation Complete!"

    echo "SciMiner URL: $SCIMINER_URL/SciMiner/"
    echo "Test Script: $SCIMINER_URL/SciMiner/test_conda_install.cgi"
    echo
    echo "Database Details:"
    echo "  - Database Name: $DB_NAME"
    echo "  - Database User: $DB_USER"
    echo "  - Database Password: $DB_PASS"
    echo
    echo "Conda Environment:"
    echo "  - Environment Name: $CONDA_ENV"
    echo "  - Environment Path: $SCIMINER_ENV_PATH"
    echo "  - Perl Path: $SCIMINER_ENV_PATH/bin/perl"
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
    echo "1. Activate conda environment: conda activate $CONDA_ENV"
    echo "2. Open $SCIMINER_URL/SciMiner/ in your browser"
    echo "3. Run the test script to verify installation"
    echo "4. Check logs if you encounter issues"
    echo "5. Read $SCIMINER_HOME/SETUP_GUIDE_CONDA.md for detailed information"
    echo
    print_warning "Note: Some Perl modules might need manual installation"
    print_warning "See the troubleshooting section in the guide for details"
}

# Main installation flow
main() {
    print_header "SciMiner Conda Installation"
    print_status "Log file: $LOG_FILE"

    check_user
    check_sudo
    init_conda
    setup_conda_env
    install_conda_packages
    install_perl_modules
    install_system_deps
    setup_database
    configure_apache
    update_shebang
    set_permissions
    create_boulder_mock
    create_test_script
    test_installation
    print_instructions

    print_status "Installation complete!"
}

# Run main function
main "$@"
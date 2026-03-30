#!/bin/bash
# SciMiner Infrastructure Setup Script - FINAL VERSION
# This script sets up Apache and MariaDB for SciMiner

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

# Function to confirm with yes/no
confirm_yesno() {
    local prompt="$1"
    local default="$2"
    local response

    while true; do
        response=$(read_input "$prompt" "$default")
        case $response in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please enter 'yes' or 'no'"
                ;;
        esac
    done
}

# Function to safely read user input
read_input() {
    local prompt="$1"
    local default="$2"
    local response

    read -p "$prompt [$default]: " response
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    echo "$response"
}

# Clear screen and show introduction
clear
echo "=============================================================================="
echo ""

# ASCII Art Banner - SciMiner
cat << 'EOF'
  ____      ____               __  __              _   _   U _____ u   ____
 / __"| uU /"___|    ___     U|' \/ '|u   ___     | \ |"|  \| ___"|/U |  _"\ u
<\___ \/ \| | u     |_"_|    \| |\/| |/  |_"_|   <|  \| |>  |  _|"   \| |_) |/
 u___) |  | |/__     | |      | |  | |    | |    U| |\  |u  | |___    |  _ <
 |____/>>  \____|  U/| |\u    |_|  |_|  U/| |\u   |_| \_|   |_____|   |_| \_\
  )(  (__)_// \\.-,_|___|_,-.<<,-,,-..-,_|___|_,-.||   \\,-.<<   >>   //   \\_
 (__)    (__)(__)\_)-' '-(_/  (./  \.)\_)-' '-(_/ (_")  (_/(__) (__) (__)  (__)

           Infrastructure Setup & Configuration Script
EOF

echo ""
echo "=============================================================================="
echo "  This script will set up the complete SciMiner environment including:"
echo "=============================================================================="
echo ""
echo "  📦  System Components:"
echo "     • Apache2 Web Server (port 8888)"
echo "     • MariaDB Database Server"
echo "     • Required Perl modules and dependencies"
echo ""
echo "  🔧  Configuration Tasks:"
echo "     • Database creation and user setup"
echo "     • Apache virtual host configuration"
echo "     • CGI script updates for system Perl"
echo "     • File permission adjustments"
echo ""
echo "  📋  What happens:"
echo "     - Checks system prerequisites"
echo "     - Installs missing components"
echo "     - Configures database (if needed)"
echo "     - Sets up proper file ownership"
echo ""
echo "  ⚠️  Requirements:"
echo "     - Must run as 'sciminer' user (not root)"
echo "     - Sudo access required for system operations"
echo "     - Internet connection for package downloads"
echo ""
echo "=============================================================================="
echo ""

# Give user a moment to read
print_status "Press Enter to continue or Ctrl+C to cancel..."
read -r

echo ""
# Check if running as correct user
print_status "Checking user permissions..."

# Get current user
CURRENT_USER=$(whoami)
SCIMINER_HOME="${SCIMINER_HOME:-/home/sciminer}"

if [[ "$CURRENT_USER" == "root" ]]; then
    print_error "This script should NOT be run as root directly"
    echo ""
    echo "Recommended approach:"
    echo "  1. Switch to sciminer user: su - sciminer"
    echo "  2. Run the script: bash SETUP_INFRASTRUCTURE_FINAL.sh"
    echo ""
    echo "This ensures files are owned by the sciminer user while using sudo for system operations."
    exit 1
fi

if [[ "$CURRENT_USER" != "sciminer" ]]; then
    print_warning "You are running as user: $CURRENT_USER"
    echo "This script is designed to run as the 'sciminer' user"
    echo ""
    read -p "Do you want to continue anyway? (y=Yes, n=No) [n]: " continue_as_user
    if [[ ! $continue_as_user =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled. Please run as sciminer user"
        exit 0
    fi
fi

# Test sudo access
echo ""
print_status "Checking sudo access..."
if ! sudo -n true 2>/dev/null; then
    echo "This script requires sudo access for system operations."
    echo "Please enter your password to continue:"
    if ! sudo -v; then
        print_error "Sudo access required. Cannot continue."
        exit 1
    fi
fi
print_success "Sudo access confirmed"
echo ""

# Function to check if service is installed

# Function to confirm with yes/no
confirm_yesno() {
    local prompt="$1"
    local default="$2"
    local response

    while true; do
        response=$(read_input "$prompt" "$default")
        case $response in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please enter 'yes' or 'no'"
                ;;
        esac
    done
}

# Function to safely read user input
read_input() {
    local prompt="$1"
    local default="$2"
    local response

    read -p "$prompt [$default]: " response
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    echo "$response"
}

# Function to confirm with yes/no
confirm_yesno() {
    local prompt="$1"
    local default="$2"
    local response

    while true; do
        response=$(read_input "$prompt" "$default")
        case $response in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please enter 'yes' or 'no'"
                ;;
        esac
    done
}

# Configuration
SCIMINER_HOME="${SCIMINER_HOME:-/home/sciminer}"
WEB_PORT="${WEB_PORT:-8888}"
DB_NAME="${DB_NAME:-sciminer}"
DB_USER="${DB_USER:-sciminer}"
DB_PASS="${DB_PASS:-124356!@}"

print_success "SciMiner Infrastructure Setup"
echo "==================================="
echo ""

# Function to check if service is installed
check_service() {
    local service=$1
    if command -v $service &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if service is running
check_service_running() {
    local service=$1
    if systemctl is-active --quiet $service; then
        return 0
    else
        return 1
    fi
}

# Stage 1: Apache Web Server Setup
echo "==================================="
echo "Stage 1: Apache Web Server Setup"
echo "==================================="

if check_service apache2; then
    print_warning "Apache2 is already installed"
    echo "Current Apache2 version: $(apache2 -v | head -n1)"
    if confirm_yesno "Do you want to reinstall/reconfigure Apache2?" "n"; then
        print_status "Reconfiguring Apache2..."
        sudo apt-get install -y --reinstall apache2
    else
        print_status "Keeping existing Apache2 installation"
    fi
else
    print_status "Installing Apache2..."
    sudo apt-get update
    sudo apt-get install -y apache2
fi

# Ensure Apache is running
if ! check_service_running apache2; then
    print_status "Starting Apache2..."
    sudo systemctl start apache2
fi
sudo systemctl enable apache2

print_success "Apache2 setup complete"

# Stage 2: Apache Configuration for SciMiner
echo ""
echo "==========================================="
echo "Stage 2: Apache Configuration for SciMiner"
echo "==========================================="

print_status "Configuring Apache for SciMiner..."

# Backup existing configuration if it exists
if [ -f /etc/apache2/sites-available/sciminer.conf ]; then
    sudo cp /etc/apache2/sites-available/sciminer.conf /etc/apache2/sites-available/sciminer.conf.backup.$(date +%Y%m%d_%H%M%S)
    print_warning "Existing Apache configuration backed up"
fi

# Create new Apache configuration
sudo tee /etc/apache2/sites-available/sciminer.conf > /dev/null << EOF
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
    echo "Listen $WEB_PORT" | sudo tee -a /etc/apache2/ports.conf > /dev/null
fi

# Restart Apache
sudo systemctl restart apache2

print_success "Apache configuration complete"

# Stage 3: MariaDB Database Setup
echo ""
echo "==================================="
echo "Stage 3: MariaDB Database Setup"
echo "==================================="

if check_service mysql || check_service mariadb; then
    if check_service mariadb; then
        DB_SERVICE="mariadb"
        print_warning "MariaDB is already installed"
    else
        DB_SERVICE="mysql"
        print_warning "MySQL is already installed (SciMiner prefers MariaDB)"
    fi
    echo "Current database version: $(mysql --version)"
    if confirm_yesno "Do you want to reinstall the database server?" "n"; then
        print_warning "This will remove your existing database server and all data!"
        read -p "Type 'DELETE' to confirm: " confirm
        if [[ $confirm == "DELETE" ]]; then
            print_status "Removing existing database..."
            sudo systemctl stop $DB_SERVICE
            sudo apt-get remove --purge -y mysql-server mariadb-server
            sudo apt-get autoremove -y
            sudo apt-get install -y mariadb-server mariadb-client
            DB_SERVICE="mariadb"
            DB_REINSTALLED="yes"
        else
            print_status "Reinstallation cancelled, keeping existing database"
            DB_REINSTALLED="no"
        fi
    else
        print_status "Keeping existing database installation"
        DB_REINSTALLED="no"
    fi
else
    print_status "Installing MariaDB..."
    sudo apt-get update
    sudo apt-get install -y mariadb-server mariadb-client
    DB_SERVICE="mariadb"
    DB_REINSTALLED="yes"
fi

# Ensure MariaDB is running
if ! check_service_running $DB_SERVICE; then
    print_status "Starting $DB_SERVICE..."
    sudo systemctl start $DB_SERVICE
fi
sudo systemctl enable $DB_SERVICE

print_success "Database setup complete"

# Stage 4: Database Status Check
echo ""
echo "==================================="
echo "Stage 4: Database Status"
echo "==================================="

# Just check if database is running, no credential prompts
if check_service_running $DB_SERVICE; then
    print_success "Database server is running"
    echo ""
    print_status "Checking database with default SciMiner credentials:"
    echo "  Database: $DB_NAME"
    echo "  Username: $DB_USER"
    echo "  Password: [Hidden - see script or configure to change]"
    echo ""

    # Quick check with default credentials (but don't prompt if it fails)
    DB_STATUS="unknown"
    if mysql -u $DB_USER -p$DB_PASS -e "SELECT 1;" &>/dev/null 2>&1; then
        print_success "Database connection successful with default credentials"
        DB_STATUS="connected"
        table_count=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "SHOW TABLES;" 2>/dev/null | wc -l 2>/dev/null || echo "0")
        if [ "$table_count" -gt 0 ]; then
            if [ "$table_count" -gt 1 ]; then
                print_success "Database '$DB_NAME' has tables configured"
                DB_STATUS="configured"
            else
                print_warning "Database '$DB_NAME' exists but no tables found"
                DB_STATUS="empty"
            fi
        else
            print_warning "Database '$DB_NAME' doesn't exist (connection to server works)"
            DB_STATUS="no_db"
        fi
    else
        print_warning "Cannot connect to database with default SciMiner credentials"
        echo "  This is normal if the database hasn't been configured yet"
        DB_STATUS="needs_config"
    fi
else
    print_error "Database server is not running"
    DB_STATUS="not_running"
fi

# Stage 5: Create SciMiner User (if doesn't exist)
echo ""
echo "==================================="
echo "Stage 5: User Account Setup"
echo "==================================="

if ! id "sciminer" &>/dev/null; then
    print_status "Creating sciminer user account..."
    useradd -m -s /bin/bash sciminer
    print_success "User 'sciminer' created"
else
    print_status "SciMiner user 'sciminer' already exists"
fi

# Stage 6: Database Configuration Option
echo ""
echo "==================================="
echo "Stage 6: Database Configuration"
echo "==================================="

if [[ $DB_STATUS == "needs_config" || $DB_STATUS == "empty" || $DB_STATUS == "no_db" || $DB_STATUS == "not_running" ]]; then
    print_warning "Database configuration is needed for SciMiner"
    echo ""
    echo "The database configuration script will:"
    echo "  - Prompt for database admin credentials"
    echo "  - Create 'sciminer' database and user if missing"
    echo "  - Import schema from sciminer.sql (if available)"
    echo "  - Update SciMiner configuration file"
    echo ""

    if confirm_yesno "Do you want to configure the database now?" "y"; then
        print_status "Starting database configuration..."
        bash "$SCIMINER_HOME/CONFIGURE_DATABASE.sh"

        # Re-check after configuration
        if mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SELECT 1;" &>/dev/null 2>&1; then
            table_count=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "SHOW TABLES;" 2>/dev/null | wc -l)
            if [ "$table_count" -gt 0 ]; then
                if [ "$table_count" -gt 1 ]; then
                    DB_STATUS="configured"
                    print_success "Database configuration completed successfully"
                else
                    DB_STATUS="empty"
                    print_status "Database configured but has no tables"
                fi
            fi
        else
            print_warning "Database configuration may have encountered issues"
            DB_STATUS="unknown"
        fi
    else
        print_status "Skipping database configuration"
        echo "Note: SciMiner will not work until database is configured"
        echo "      You can run it later with: sudo bash $SCIMINER_HOME/CONFIGURE_DATABASE.sh"
    fi
else
    print_success "Database appears to be configured"
    echo ""
    if confirm_yesno "Do you want to reconfigure the database?" "n"; then
        print_status "Starting database reconfiguration..."
        bash "$SCIMINER_HOME/CONFIGURE_DATABASE.sh"

        # Re-check after configuration
        if mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SELECT 1;" &>/dev/null 2>&1; then
            table_count=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "SHOW TABLES;" 2>/dev/null | wc -l)
            if [ "$table_count" -gt 0 ]; then
                if [ "$table_count" -gt 1 ]; then
                    print_success "Database reconfiguration completed successfully"
                    DB_STATUS="configured"
                else
                    print_status "Database reconfigured but has no tables"
                    DB_STATUS="empty"
                fi
            fi
        else
            print_warning "Database reconfiguration may have encountered issues"
            DB_STATUS="unknown"
        fi
    else
        print_status "Keeping existing database configuration"
    fi
fi

# Stage 6: Install Perl Modules
echo ""
echo "==================================="
echo "Stage 6: Perl Modules Installation"
echo "==================================="

print_status "Installing required Perl modules for SciMiner..."

# Track Perl modules installation status
PERL_MODULES_INSTALLED=false

# Proceed with installation (sudo was verified at script start)
    # Sub-stage 6.1: Install Build Tools and Development Headers
    echo ""
    print_status "6.1: Installing build tools and headers..."

    # Update package lists
    print_status "  Updating package lists..."
    sudo apt-get update >/dev/null 2>&1

    # Install build tools
    print_status "  Installing build tools..."
    BUILD_TOOLS="build-essential gcc make pkg-config libc6-dev"
    for tool in $BUILD_TOOLS; do
        echo "  - $tool"
    done
    sudo apt-get install -y $BUILD_TOOLS >/dev/null 2>&1
    echo "  ✓ Build tools installed"

    # Install development headers
    print_status "  Installing development headers..."
    DEV_HEADERS="libxml2-dev libyaml-dev zlib1g-dev libmysqlclient-dev"
    for header in $DEV_HEADERS; do
        echo "  - $header"
    done
    sudo apt-get install -y $DEV_HEADERS >/dev/null 2>&1
    echo "  ✓ Development headers installed"

    # Sub-stage 6.2: Install System Perl Packages
    echo ""
    print_status "6.2: Installing system Perl packages..."

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
    apt_installed=0
    apt_already=0
    for package in "${APT_PACKAGES[@]}"; do
        if apt-cache show "$package" &> /dev/null; then
            # Check if package is already installed
            if dpkg -l "$package" &> /dev/null; then
                echo "  ✓ $package (already installed)"
                apt_already=$((apt_already + 1))
            else
                print_status "  Installing $package..."
                if sudo apt-get install -y "$package" >/dev/null 2>&1; then
                    echo "    ✓ $package installed"
                    apt_installed=$((apt_installed + 1))
                else
                    echo "    ✗ Failed to install $package"
                fi
            fi
        else
            print_status "  Skipping $package (not available in this Ubuntu version)"
        fi
    done
    print_success "System packages check complete:"
    echo "  ✓ Already installed: $apt_already packages"
    if [ $apt_installed -gt 0 ]; then
        echo "  ✓ Newly installed: $apt_installed packages"
    fi
    echo "  Total available: ${#APT_PACKAGES[@]} packages"

    # Sub-stage 6.3: Install CPAN Modules
    echo ""
    print_status "6.3: Installing CPAN modules..."

    # Install cpanminus if not available
    if ! command -v cpanm >/dev/null 2>&1; then
        sudo apt-get install -y cpanminus >/dev/null 2>&1 || cpan App::cpanminus >/dev/null 2>&1
    fi

    # List of modules to install via CPAN
    CPAN_MODULES=(
        "Text::NSP"
        "CGI::Application"
        "Spreadsheet::WriteExcel"
        "Boulder::Medline"
        "YAML::XS"
        "Unicode::String"
        "LWP::UserAgent"
        "CGI::Debug"
        "Crypt::Eksblowfish::Bcrypt"
    )

    cpan_installed=0
    cpan_failed=0
    for module in "${CPAN_MODULES[@]}"; do
        if perl -M"$module" -e '1' 2>/dev/null; then
            echo "  ✓ $module (already installed)"
            cpan_installed=$((cpan_installed + 1))
        else
            print_status "  Installing $module via CPAN..."
            if cpanm --notest "$module" >/dev/null 2>&1; then
                echo "    ✓ $module installed successfully"
                cpan_installed=$((cpan_installed + 1))
            else
                echo "    ✗ Failed to install $module"
                cpan_failed=$((cpan_failed + 1))
            fi
        fi
    done
    print_success "CPAN modules installation complete:"
    echo "  ✓ Installed: $cpan_installed modules"
    if [ $cpan_failed -gt 0 ]; then
        print_warning "  ✗ Failed: $cpan_failed modules"
    fi

    # Sub-stage 6.4: Fix Known Issues
    echo ""
    print_status "6.4: Fixing known module issues..."

    # Fix Boulder::Medline syntax errors if installed
    MEDLINE_PATH=$(find /usr -name "Medline.pm" 2>/dev/null | grep Boulder | head -1)
    if [ -n "$MEDLINE_PATH" ] && [ -f "$MEDLINE_PATH" ]; then
        if grep -q "\$line=@recordlines\[" "$MEDLINE_PATH" 2>/dev/null; then
            print_status "Fixing Boulder::Medline syntax errors..."

            # Check if syntax issues exist before attempting fixes
            SYNTAX_ISSUES=0

            # Check for the array syntax issue
            if grep -q "\$line=@recordlines\[" "$MEDLINE_PATH" 2>/dev/null; then
                SYNTAX_ISSUES=$((SYNTAX_ISSUES + 1))
            fi

            # Check for loop variable declaration
            if grep -q "for (\$i=" "$MEDLINE_PATH" 2>/dev/null; then
                SYNTAX_ISSUES=$((SYNTAX_ISSUES + 1))
            fi

            # Check for missing variable declaration
            if ! grep -q "my(\$junk, \$ui, \$da, \$pmid, \$ad, \$so);" "$MEDLINE_PATH" 2>/dev/null; then
                SYNTAX_ISSUES=$((SYNTAX_ISSUES + 1))
            fi

            if [ $SYNTAX_ISSUES -gt 0 ]; then
                # Apply fixes
                print_status "  Backing up original file..."
                sudo cp "$MEDLINE_PATH" "${MEDLINE_PATH}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null

                print_status "  Applying syntax fixes..."
                if grep -q "\$line=@recordlines\[" "$MEDLINE_PATH" 2>/dev/null; then
                    sudo sed -i 's/$line=@recordlines\[$i\];/$line=$recordlines[$i];/' "$MEDLINE_PATH" 2>/dev/null
                    echo "    ✓ Fixed array syntax"
                fi

                if grep -q "for (\$i=" "$MEDLINE_PATH" 2>/dev/null; then
                    sudo sed -i 's/for (\$i=/for (my $i=/' "$MEDLINE_PATH" 2>/dev/null
                    echo "    ✓ Fixed loop variable declaration"
                fi

                if ! grep -q "my(\$junk, \$ui, \$da, \$pmid, \$ad, \$so);" "$MEDLINE_PATH" 2>/dev/null; then
                    sudo sed -i '263a my($junk, $ui, $da, $pmid, $ad, $so);' "$MEDLINE_PATH" 2>/dev/null
                    echo "    ✓ Added missing variable declaration"
                fi

                # Verify syntax after fixes
                if perl -c "$MEDLINE_PATH" 2>/dev/null; then
                    print_success "Boulder::Medline syntax fixed successfully"
                else
                    print_warning "Boulder::Medline may still have syntax issues"
                fi
            else
                print_status "Boulder::Medline syntax already correct"
            fi
        else
            print_status "Boulder::Medline syntax already correct"
        fi
    fi

    # Sub-stage 6.5: Update CGI Scripts
    echo ""
    print_status "6.5: Updating CGI scripts to use system Perl..."

    CGI_SCRIPTS=$(find $SCIMINER_HOME/web/html -name "*.cgi" -type f 2>/dev/null)
    if [ -n "$CGI_SCRIPTS" ]; then
        updated=0
        for script in $CGI_SCRIPTS; do
            if grep -q "#!/home/sciminer/miniconda3" "$script" 2>/dev/null; then
                sed -i 's|#!/home/sciminer/miniconda3/envs/sciminer/bin/perl|#!/usr/bin/perl|g' "$script" 2>/dev/null
                chmod +x "$script" 2>/dev/null
                updated=$((updated + 1))
            fi
        done
        print_success "Updated $updated CGI scripts to use system Perl"
    fi

    print_success "Perl modules installation complete"

    # Mark Perl modules as successfully installed
    PERL_MODULES_INSTALLED=true

# Stage 7: Final Configuration
echo ""
echo "==================================="
echo "Stage 7: Final Configuration"
echo "==================================="

# Set proper permissions
sudo chown -R sciminer:sciminer $SCIMINER_HOME 2>/dev/null || true
find $SCIMINER_HOME/web/html -name "*.cgi" -exec chmod +x {} \; 2>/dev/null || true

# Create a test HTML page to verify Apache is working
mkdir -p $SCIMINER_HOME/web/html
cat > $SCIMINER_HOME/web/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SciMiner - Infrastructure Test</title>
</head>
<body>
    <h1>SciMiner Infrastructure Setup Complete</h1>
    <p>If you see this page, Apache is working correctly!</p>
    <p>Next step: Run the Perl module installation script</p>
    <p><a href="/SciMiner/">Go to SciMiner Directory</a></p>
</body>
</html>
EOF

sudo chown sciminer:sciminer $SCIMINER_HOME/web/html/index.html 2>/dev/null || true

# Final status
echo ""
echo "==================================="
print_success "SciMiner Setup Complete!"
echo "==================================="
echo ""
echo "Status Summary:"
echo "  Apache2: $(systemctl is-active apache2)"
echo "  MariaDB: $(systemctl is-active $DB_SERVICE)"
echo "  Web Port: $WEB_PORT"
echo ""
echo "Database Status:"
case $DB_STATUS in
    "configured")
        echo "  ✓ Fully configured and ready"
        ;;
    "connected")
        echo "  ✓ Connection works but needs schema import"
        ;;
    "empty")
        echo "  ✓ Connection works, database exists, but no tables"
        ;;
    "no_db")
        echo "  ✓ Connection works, but database doesn't exist"
        ;;
    "needs_config")
        echo "  ✗ Database connection needs configuration"
        ;;
    "not_running")
        echo "  ✗ Database server not running"
        ;;
    *)
        echo "  ? Unknown status"
        ;;
esac
echo ""
echo "Perl Modules Status:"
if [[ $PERL_MODULES_INSTALLED == true ]]; then
    echo "  ✓ Installation completed in Stage 6"
else
    echo "  ⚠ Skipped (requires sudo)"
    echo "    Run: sudo bash $SCIMINER_HOME/INSTALL_PERL_MODULES.sh"
fi
echo ""
echo "Test the web server:"
echo "  curl http://localhost:$WEB_PORT/"
echo ""
echo "Next Steps:"
if [[ $DB_STATUS == "needs_config" || $DB_STATUS == "empty" || $DB_STATUS == "no_db" || $DB_STATUS == "not_running" ]]; then
    echo "  1. Configure database: sudo bash $SCIMINER_HOME/CONFIGURE_DATABASE.sh"
    if [[ $PERL_MODULES_INSTALLED != true ]]; then
        echo "  2. Install Perl modules: sudo bash $SCIMINER_HOME/INSTALL_PERL_MODULES.sh"
        echo "  3. Test SciMiner: curl http://localhost:$WEB_PORT/SciMiner/"
    else
        echo "  2. Test SciMiner: curl http://localhost:$WEB_PORT/SciMiner/"
    fi
else
    if [[ $PERL_MODULES_INSTALLED != true ]]; then
        echo "  1. Install Perl modules: sudo bash $SCIMINER_HOME/INSTALL_PERL_MODULES.sh"
        echo "  2. Test SciMiner: curl http://localhost:$WEB_PORT/SciMiner/"
    else
        echo "  1. Test SciMiner: curl http://localhost:$WEB_PORT/SciMiner/"
    fi
fi

echo ""
echo "Configuration Files:"
echo "  Apache: /etc/apache2/sites-available/sciminer.conf"
echo "  SciMiner: $SCIMINER_HOME/ANNOTATION/SciMinerDB/annotationENV.ini"
echo ""
echo "Logs:"
echo "  Apache: /var/log/apache2/sciminer_error.log"
echo "  MariaDB: /var/log/mysql/error.log"
echo ""
echo "⚠️  IMPORTANT:"
echo "  - Configure database before running SciMiner"
echo "  - Change default database password for production"
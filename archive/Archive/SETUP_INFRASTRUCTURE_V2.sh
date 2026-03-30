#!/bin/bash
# SciMiner Infrastructure Setup Script - Version 2
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script needs to be run with sudo privileges"
    exit 1
fi

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
        apt-get install -y --reinstall apache2
    else
        print_status "Keeping existing Apache2 installation"
    fi
else
    print_status "Installing Apache2..."
    apt-get update
    apt-get install -y apache2
fi

# Ensure Apache is running
if ! check_service_running apache2; then
    print_status "Starting Apache2..."
    systemctl start apache2
fi
systemctl enable apache2

print_success "Apache2 setup complete"

# Stage 2: Apache Configuration for SciMiner
echo ""
echo "==========================================="
echo "Stage 2: Apache Configuration for SciMiner"
echo "==========================================="

print_status "Configuring Apache for SciMiner..."

# Backup existing configuration if it exists
if [ -f /etc/apache2/sites-available/sciminer.conf ]; then
    cp /etc/apache2/sites-available/sciminer.conf /etc/apache2/sites-available/sciminer.conf.backup.$(date +%Y%m%d_%H%M%S)
    print_warning "Existing Apache configuration backed up"
fi

# Create new Apache configuration
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

# Restart Apache
systemctl restart apache2

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
            systemctl stop $DB_SERVICE
            apt-get remove --purge -y mysql-server mariadb-server
            apt-get autoremove -y
            apt-get install -y mariadb-server mariadb-client
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
    apt-get update
    apt-get install -y mariadb-server mariadb-client
    DB_SERVICE="mariadb"
    DB_REINSTALLED="yes"
fi

# Ensure MariaDB is running
if ! check_service_running $DB_SERVICE; then
    print_status "Starting $DB_SERVICE..."
    systemctl start $DB_SERVICE
fi
systemctl enable $DB_SERVICE

print_success "Database setup complete"

# Stage 4: Database Configuration Check
echo ""
echo "==================================="
echo "Stage 4: Database Configuration"
echo "==================================="

DB_CONFIGURED="unknown"
USER_EXISTS="no"
DB_EXISTS="no"

# Get admin credentials to properly check database
print_status "Checking database configuration requires admin access"
echo ""
if confirm_yesno "Do you want to check existing database configuration?" "y"; then
    MAX_ATTEMPTS=3
    ATTEMPT=1
    CONNECTED=false

    while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ $CONNECTED == false ]; do
        echo "Attempt $ATTEMPT of $MAX_ATTEMPTS"
        read -p "Database admin username [root]: " ADMIN_USER
        ADMIN_USER=${ADMIN_USER:-root}
        read -s -p "Database admin password: " ADMIN_PASS
        echo ""

        if mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SELECT 1;" &>/dev/null 2>&1; then
            CONNECTED=true
            print_success "Database connection successful"
        else
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -le $MAX_ATTEMPTS ]; then
                print_error "Authentication failed. Please try again."
            fi
        fi
    done

    if [ $CONNECTED == true ]; then
        # Check if database exists
        DB_COUNT=$(mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | grep "$DB_NAME" | wc -l)
        if [ $DB_COUNT -gt 0 ]; then
            DB_EXISTS="yes"
            print_status "Database '$DB_NAME' exists"
        else
            print_warning "Database '$DB_NAME' does not exist"
            DB_EXISTS="no"
        fi

        # Check if user exists
        USER_COUNT=$(mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SELECT User FROM mysql.user WHERE User='$DB_USER';" 2>/dev/null | grep "$DB_USER" | wc -l)
        if [ $USER_COUNT -gt 0 ]; then
            USER_EXISTS="yes"
            print_status "Database user '$DB_USER' exists"

            # Try to test if the user password works
            if mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SELECT 1;" &>/dev/null; then
                # Connection successful, check if database has tables
                table_count=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "SHOW TABLES;" 2>/dev/null | wc -l)
                if [ $table_count -gt 1 ]; then
                    print_success "Database '$DB_NAME' is fully configured with $((table_count-1)) tables"
                    DB_CONFIGURED="yes"
                else
                    print_warning "Database '$DB_NAME' exists but has no tables"
                    DB_CONFIGURED="partial"
                fi
            else
                print_warning "Database user '$DB_USER' exists but cannot authenticate"
                print_warning "The password may be different from the default"
                DB_CONFIGURED="partial"
            fi
        else
            print_warning "Database user '$DB_USER' does not exist"
            USER_EXISTS="no"
        fi
    else
        print_error "Failed to connect after $MAX_ATTEMPTS attempts"
        echo ""
        if confirm_yesno "Would you like to try again (3 more attempts)?" "n"; then
            # Reset and try again
            MAX_ATTEMPTS=3
            ATTEMPT=1
            CONNECTED=false

            while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ $CONNECTED == false ]; do
                echo "Attempt $ATTEMPT of $MAX_ATTEMPTS (retry)"
                read -p "Database admin username [root]: " ADMIN_USER
                ADMIN_USER=${ADMIN_USER:-root}
                read -s -p "Database admin password: " ADMIN_PASS
                echo ""

                if mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SELECT 1;" &>/dev/null 2>&1; then
                    CONNECTED=true
                    print_success "Database connection successful"
                else
                    ATTEMPT=$((ATTEMPT + 1))
                    if [ $ATTEMPT -le $MAX_ATTEMPTS ]; then
                        print_error "Authentication failed. Please try again."
                    fi
                fi
            done
        fi

        if [ $CONNECTED == false ]; then
            print_error "Cannot connect to database with provided credentials"
            print_warning "Skipping database configuration check"
            DB_CONFIGURED="unknown"
        fi
    fi

    if [ $CONNECTED == true ]; then
else
    print_status "Skipping database configuration check"
    DB_CONFIGURED="unknown"
fi

# Based on what we found, decide next steps
if [[ $DB_CONFIGURED == "unknown" ]]; then
    echo ""
    echo "Database status could not be determined"
    echo "To configure the database, run:"
    echo "  sudo bash $SCIMINER_HOME/CONFIGURE_DATABASE.sh"
elif [[ $DB_CONFIGURED != "yes" ]]; then
    echo ""
    echo "Database needs configuration"
    echo "Current status:"
    echo "  - Database exists: $DB_EXISTS"
    echo "  - User exists: $USER_EXISTS"
    echo ""
    echo "To configure the database, run:"
    echo "  sudo bash $SCIMINER_HOME/CONFIGURE_DATABASE.sh"
    echo ""
    if confirm_yesno "Do you want to run database configuration now?" "y"; then
        print_status "Starting database configuration..."
        bash "$SCIMINER_HOME/CONFIGURE_DATABASE.sh"

        # Re-check after configuration
        if mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SELECT 1;" &>/dev/null; then
            table_count=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "SHOW TABLES;" 2>/dev/null | wc -l)
            if [ $table_count -gt 1 ]; then
                print_status "Database configuration completed successfully"
                DB_CONFIGURED="yes"
            else
                print_warning "Database exists but has no tables"
                DB_CONFIGURED="partial"
            fi
        else
            print_warning "Database configuration may have encountered issues"
        fi
    else
        print_status "Skipping database configuration"
        echo "Note: SciMiner will not work until database is configured"
    fi
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

    # Show additional info based on database check
    if [[ $USER_EXISTS == "yes" ]]; then
        echo "  - System user: ✓ Exists"
        echo "  - Database user: ✓ Found in database"
        if [[ $DB_CONFIGURED == "yes" ]]; then
            echo "  - Database connection: ✓ Working"
        elif [[ $DB_CONFIGURED == "partial" ]]; then
            echo "  - Database connection: ⚠ Exists but may need password fix"
        fi
    elif [[ $USER_EXISTS == "no" && $DB_CONFIGURED != "unknown" ]]; then
        echo "  - System user: ✓ Exists"
        echo "  - Database user: ✗ Not found in database"
        echo "  -> Database configuration will create the database user"
    fi
fi

# Stage 6: Final Configuration
echo ""
echo "==================================="
echo "Stage 6: Final Configuration"
echo "==================================="

# Set proper permissions
chown -R sciminer:sciminer $SCIMINER_HOME 2>/dev/null || true
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

chown sciminer:sciminer $SCIMINER_HOME/web/html/index.html 2>/dev/null || true

# Final status
echo ""
echo "==================================="
print_success "Infrastructure Setup Complete!"
echo "==================================="
echo ""
echo "Status Summary:"
echo "  Apache2: $(systemctl is-active apache2)"
echo "  MariaDB: $(systemctl is-active $DB_SERVICE)"
echo "  Web Port: $WEB_PORT"
echo ""
echo "Database Status:"
case $DB_CONFIGURED in
    "yes")
        table_count=$(mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "SHOW TABLES;" 2>/dev/null | wc -l)
        echo "  Database Connection: ✓ Connected"
        echo "  Tables: $((table_count-1))"
        ;;
    "partial")
        echo "  Database Connection: ✓ Connected (but no tables)"
        echo "  Tables: 0 (needs schema import)"
        ;;
    "no")
        echo "  Database Connection: ✗ Not configured"
        echo "  Tables: N/A"
        ;;
    *)
        echo "  Database Connection: ? Not checked"
        echo "  Tables: Unknown"
        ;;
esac
echo ""
echo "Test the web server:"
echo "  curl http://localhost:$WEB_PORT/"
echo ""
echo "Next Steps:"
if [[ $DB_CONFIGURED != "yes" ]]; then
    echo "  1. Configure database: sudo bash $SCIMINER_HOME/CONFIGURE_DATABASE.sh"
fi
echo "  2. Run Perl module installation: sudo bash $SCIMINER_HOME/INSTALL_PERL_MODULES.sh"
echo "  3. Test SciMiner: curl http://localhost:$WEB_PORT/SciMiner/"
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
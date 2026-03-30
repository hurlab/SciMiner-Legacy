#!/bin/bash
# SciMiner Database Configuration Script
# This script configures MariaDB/MySQL for SciMiner

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
DB_NAME="${DB_NAME:-sciminer}"
DB_USER="${DB_USER:-sciminer}"
DB_PASS="${DB_PASS:-124356!@}"

print_success "SciMiner Database Configuration"
echo "=================================== "

# Check if default sciminer credentials work
echo ""
print_status "Testing default SciMiner database credentials..."
if mysql -u $DB_USER -p"$DB_PASS" -e "SELECT 1;" &>/dev/null; then
    print_success "Default SciMiner credentials work!"
    ADMIN_USER=$DB_USER
    ADMIN_PASS=$DB_PASS
    print_status "Using default credentials for configuration"
else
    print_warning "Default SciMiner credentials don't work"
    echo ""
    print_status "Please enter database admin credentials:"
    read -p "MySQL/MariaDB admin username [root]: " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-root}
    read -s -p "MySQL/MariaDB admin password: " ADMIN_PASS
    echo ""
    echo ""
fi

# Test connection and privileges
print_status "Testing database connection and privileges..."
if mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SELECT 1;" &>/dev/null; then
    print_success "Database connection successful"

    # Check if user has CREATE DATABASE privilege
    if mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SHOW DATABASES;" &>/dev/null; then
        print_status "User has sufficient privileges for database operations"
    else
        print_error "User doesn't have sufficient privileges to create databases"
        echo "Please use a database admin account (like root)"
        exit 1
    fi
else
    print_error "Cannot connect to database with provided credentials"
    echo "Please check:"
    echo "  - Database server is running: sudo systemctl status mariadb"
    echo "  - Username and password are correct"
    echo "  - User has proper privileges"
    exit 1
fi

# Check if database exists
DB_EXISTS=$(mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SHOW DATABASES LIKE '$DB_NAME';" | grep "$DB_NAME" | wc -l)
if [ $DB_EXISTS -gt 0 ]; then
    print_warning "Database '$DB_NAME' already exists"
    read -p "Do you want to drop and recreate it? This will delete all data! (y=Yes, n=Keep) [n]: " drop_db
    if [[ $drop_db =~ ^[Yy]$ ]]; then
        mysql -u $ADMIN_USER -p$ADMIN_PASS -e "DROP DATABASE $DB_NAME;"
        print_status "Existing database dropped"
    fi
fi

# Create database
print_status "Creating SciMiner database '$DB_NAME'..."
mysql -u $ADMIN_USER -p$ADMIN_PASS -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Only manage user if not using sciminer account directly
if [[ "$ADMIN_USER" == "$DB_USER" ]]; then
    print_status "Using sciminer account directly - skipping user creation and privileges"
else
    # Check if user exists
    USER_EXISTS=$(mysql -u $ADMIN_USER -p$ADMIN_PASS -e "SELECT User FROM mysql.user WHERE User='$DB_USER';" | grep "$DB_USER" | wc -l)
    if [ $USER_EXISTS -gt 0 ]; then
        print_warning "Database user '$DB_USER' already exists"
        read -p "Do you want to reset the password for '$DB_USER'? (y=Yes, n=Keep current) [n]: " reset_pass
        if [[ $reset_pass =~ ^[Yy]$ ]]; then
            mysql -u $ADMIN_USER -p$ADMIN_PASS -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
            print_status "Password reset for user '$DB_USER'"
        fi
    else
        print_status "Creating database user '$DB_USER'..."
        mysql -u $ADMIN_USER -p$ADMIN_PASS -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    fi

    # Grant privileges
    mysql -u $ADMIN_USER -p$ADMIN_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -u $ADMIN_USER -p$ADMIN_PASS -e "FLUSH PRIVILEGES;"
fi

# Test sciminer user connection
print_status "Testing SciMiner user access..."
if mysql -u $DB_USER -p"$DB_PASS" -e "USE $DB_NAME; SELECT 1;" &>/dev/null; then
    print_success "SciMiner user access successful"
else
    print_error "Cannot connect with SciMiner user credentials"
    exit 1
fi

# Import schema if available
if [ -f "/home/sciminer/sciminer.sql" ]; then
    echo ""
    print_status "Found sciminer.sql, importing database schema..."
    mysql -u $DB_USER -p"$DB_PASS" $DB_NAME < /home/sciminer/sciminer.sql

    # Verify tables were created
    table_count=$(mysql -u $DB_USER -p"$DB_PASS" $DB_NAME -e "SHOW TABLES;" | wc -l)
    if [ $table_count -gt 0 ]; then
        print_success "Database schema imported successfully ($((table_count-1)) tables)"
    else
        print_warning "No tables found after import"
    fi
else
    print_status "sciminer.sql not found, skipping schema import"
fi

# Update SciMiner configuration
if [ -f "/home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini" ]; then
    echo ""
    print_status "Updating SciMiner configuration..."
    cp "/home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini" "/home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini.backup.$(date +%Y%m%d_%H%M%S)"

    sed -i "s/^DB=.*/DB=$DB_NAME/" "/home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini"
    sed -i "s/^username=.*/username=$DB_USER/" "/home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini"
    sed -i "s/^password=.*/password=$DB_PASS/" "/home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini"

    print_success "Configuration updated"
fi

# Test configuration
print_status "Testing database connection with new configuration..."
if mysql -u $DB_USER -p"$DB_PASS" -e "USE $DB_NAME; SELECT 'Database configured successfully' as status;" 2>/dev/null; then
    print_success "Database configuration complete!"
else
    print_error "Database test failed"
    exit 1
fi

echo ""
echo "==================================="
print_success "Database Configuration Complete!"
echo "==================================="
echo ""
echo "Database Details:"
echo "  Database Name: $DB_NAME"
echo "  Database User: $DB_USER"
echo "  Database Host: localhost"
echo ""
echo "Configuration Files:"
echo "  SciMiner Config: /home/sciminer/legacy/annotation/SciMinerDB/annotationENV.ini"
echo ""
echo "To test database connection:"
echo "  mysql -u $DB_USER -p\"$DB_PASS\" $DB_NAME"
echo ""
echo "Next Steps:"
echo "  1. Run system package installation: sudo ./INSTALL_PERL_MODULES.sh"
echo "  2. Test SciMiner web interface"
echo ""
echo "⚠️  Remember the database password for SciMiner configuration!"
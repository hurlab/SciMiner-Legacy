# MariaDB Migration Guide for SciMiner

## Overview
This guide covers migrating from MySQL to MariaDB for SciMiner, which provides better compatibility with Linux distributions and is fully open-source.

## Benefits of MariaDB over MySQL
- Fully open-source (no Oracle licensing concerns)
- Better performance in many scenarios
- Drop-in replacement for MySQL
- More storage engine options
- Enhanced security features

## Prerequisites
- Current MySQL data backed up
- Administrative access to the system
- SciMiner not currently running critical operations

## Migration Steps

### 1. Backup Current MySQL Data (IMPORTANT!)
```bash
# Create a complete backup of your current database
mysqldump -u sciminer -p sciminer > sciminer_mysql_backup_$(date +%Y%m%d).sql

# Also backup all databases
mysqldump -u root -p --all-databases > all_databases_backup_$(date +%Y%m%d).sql
```

### 2. Stop MySQL Service
```bash
sudo systemctl stop mysql
# OR
sudo service mysql stop
```

### 3. Remove MySQL
```bash
# Remove MySQL server and client
sudo apt-get remove --purge mysql-server mysql-client mysql-common
sudo apt-get autoremove
sudo apt-get autoclean
```

### 4. Install MariaDB
```bash
# Update package list
sudo apt-get update

# Install MariaDB server and client
sudo apt-get install -y mariadb-server mariadb-client

# Secure the installation
sudo mysql_secure_installation
```

### 5. Start MariaDB Service
```bash
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Check status
sudo systemctl status mariadb
```

### 6. Create SciMiner Database and User in MariaDB

#### Step 6.1: Secure Root Account and Create SciMiner User
```bash
# Log in to MariaDB as root
sudo mysql -u root

# In MariaDB shell:
-- Set password for root account
ALTER USER 'root'@'localhost' IDENTIFIED BY '124356!@';
FLUSH PRIVILEGES;

-- Exit and log back in with password
EXIT;

# Log in with password
sudo mysql -u root -p124356!

-- Create the sciminer user with the same password
CREATE USER 'sciminer'@'localhost' IDENTIFIED BY '124356!@';

-- Create SciMiner database
CREATE DATABASE sciminer CHARACTER SET latin1 COLLATE latin1_swedish_ci;

-- Grant full privileges for all databases to sciminer (development setup)
GRANT ALL PRIVILEGES ON *.* TO 'sciminer'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

### ⚠️  PRODUCTION SECURITY SETUP (CRITICAL!)

**For production deployment, the sciminer user should have limited privileges to only the sciminer database:**

```bash
# Log in as root
sudo mysql -u root -p124356!

-- Create production sciminer user with limited privileges
DROP USER IF EXISTS 'sciminer'@'localhost';
CREATE USER 'sciminer'@'localhost' IDENTIFIED BY '124356!@';

-- Grant privileges ONLY to sciminer database
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, INDEX, CREATE TEMPORARY TABLES
ON sciminer.* TO 'sciminer'@'localhost';

-- Optional: Grant FILE privilege if needed for imports (use with caution)
-- GRANT FILE ON *.* TO 'sciminer'@'localhost';

FLUSH PRIVILEGES;
EXIT;
```

### 6.2: Verify User Creation
```bash
# Test sciminer user access
mysql -u sciminer -p124356!@ -e "SHOW DATABASES;"

# Test access to sciminer database
mysql -u sciminer -p124356!@ sciminer -e "SHOW TABLES;"
```

### 7. Restore Data (if you have a backup)
```bash
# Restore your data
mysql -u sciminer -p sciminer < sciminer_mysql_backup_YYYYMMDD.sql
```

### 8. Update SciMiner Configuration
No changes needed! MariaDB is a drop-in replacement for MySQL. The existing DBD::MySQL module will work with MariaDB.

### 9. Install DBD::MariaDB (Optional but Recommended)
```bash
# Install MariaDB native driver (better performance)
sudo apt-get install -y libdbd-mariadb-perl

# OR install via cpanm
cpanm -i DBD::MariaDB
```

### 10. Verify Connection
```bash
# Test connection
mysql -u sciminer -p sciminer -e "SELECT VERSION();"

# Check tables
mysql -u sciminer -p sciminer -e "SHOW TABLES;"
```

## Configuration Files

### MariaDB Configuration Location
- Main config: `/etc/mysql/mariadb.conf.d/50-server.cnf`
- Client config: `/etc/mysql/mariadb.conf.d/50-client.cnf`

### Recommended MariaDB Settings for SciMiner
Edit `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```ini
[mysqld]
# Basic settings
bind-address = 127.0.0.1
port = 3306

# Character set
character-set-server  = latin1
collation-server      = latin1_swedish_ci

# Performance settings
innodb_buffer_pool_size = 1G
innodb_log_file_size     = 256M
innodb_flush_log_at_trx_commit = 2

# Connection settings
max_connections        = 100
connect_timeout         = 5
wait_timeout            = 600
max_allowed_packet      = 64M

# Query cache
query_cache_type        = 1
query_cache_size        = 64M

# Slow query log
slow_query_log          = 1
slow_query_log_file     = /var/log/mysql/mariadb-slow.log
long_query_time         = 2
```

Restart MariaDB after changes:
```bash
sudo systemctl restart mariadb
```

## Perl DBI Configuration Update

### Option 1: Keep using DBD::MySQL
No changes needed - DBD::MySQL works with MariaDB.

### Option 2: Switch to DBD::MariaDB (Recommended)
Update your database connection string:

```perl
# In your Perl code, change from:
my $dsn = "DBI:mysql:database=sciminer;host=localhost";

# To:
my $dsn = "DBI:MariaDB:database=sciminer;host=localhost";
```

### Update annotationENV.ini
If using DBD::MariaDB, update:
```ini
# No change needed for DBD::MySQL
# DBD::MariaDB uses the same driver name
DBDRIVER=mysql
```

## Verification Commands

### Check MariaDB Version
```bash
mysql -V
# Should show: mariadb Ver 15.x Distrib
```

### Check Running Processes
```bash
ps aux | grep mariadb
# OR
ps aux | grep mysql
```

### Check Port
```bash
sudo netstat -tlnp | grep :3306
```

### Test from Perl
```perl
#!/usr/bin/perl
use DBI;

my $dsn = "DBI:mysql:database=sciminer;host=localhost";
my $user = "sciminer";
my $pass = "your_password";

eval {
    my $dbh = DBI->connect($dsn, $user, $pass);
    if ($dbh) {
        print "SUCCESS: Connected to MariaDB\n";
        print "Server Info: " . $dbh->{mysql_serverinfo} . "\n";
        $dbh->disconnect();
    }
};

if ($@) {
    print "ERROR: $@\n";
}
```

## Troubleshooting

### If Connection Fails
1. Check MariaDB is running: `sudo systemctl status mariadb`
2. Check credentials: `mysql -u sciminer -p`
3. Check firewall settings
4. Verify database exists: `SHOW DATABASES;`

### If Performance Issues
1. Check slow query log
2. Optimize innodb_buffer_pool_size
3. Check MariaDB error log: `sudo tail -f /var/log/mysql/error.log`

### If Module Issues
```bash
# Install MariaDB development libraries
sudo apt-get install -y libmariadb-dev libmariadbclient-dev

# Reinstall DBD modules
cpanm --force --reinstall DBD::MySQL
```

## Migration Checklist

### Development Setup
- [ ] Backup all MySQL databases
- [ ] Stop MySQL service
- [ ] Remove MySQL packages
- [ ] Install MariaDB
- [ ] Start MariaDB service
- [ ] Create database and user with full privileges
- [ ] Restore data from backup
- [ ] Update configuration (if needed)
- [ ] Test application connectivity
- [ ] Verify all functions work
- [ ] Update documentation

### ⚠️  PRODUCTION DEPLOYMENT (Mandatory)
- [ ] **Set strong root password** (not the example password)
- [ ] **Create sciminer user with LIMITED privileges** (see Production Security Setup)
- [ ] **Restrict sciminer user to sciminer database only**
- [ ] **Remove grant option from sciminer user** (unless absolutely necessary)
- [ ] **Disable remote root access**
- [ ] **Test that sciminer user cannot access other databases**
- [ ] **Verify application works with limited privileges**
- [ ] **Document all passwords securely** (not in version control)

## Rollback Plan (If Needed)

If you need to rollback to MySQL:

```bash
# Stop MariaDB
sudo systemctl stop mariadb

# Backup MariaDB data
mysqldump -u root -p --all-databases > mariadb_backup.sql

# Remove MariaDB
sudo apt-get remove --purge mariadb-server mariadb-client

# Install MySQL
sudo apt-get install -y mysql-server mysql-client

# Restore data
mysql -u root -p < all_databases_backup_YYYYMMDD.sql
```

## Benefits After Migration

1. **Better Performance**: MariaDB often shows 5-10% performance improvement
2. **No Licensing Issues**: Fully GPL licensed
3. **More Features**: Additional storage engines like Aria, Spider
4. **Better Monitoring**: Enhanced performance schema
5. **Active Development**: Faster release cycle with new features

### Security Best Practices

### User Privilege Management
```sql
-- View current users and their privileges
SELECT User, Host, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv
FROM mysql.user;

-- View database-specific privileges
SELECT * FROM mysql.db WHERE User = 'sciminer';

-- View grants for specific user
SHOW GRANTS FOR 'sciminer'@'localhost';
```

### Recommended Production Privileges for SciMiner
```sql
-- Minimum required privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON sciminer.* TO 'sciminer'@'localhost';
GRANT CREATE TEMPORARY TABLES ON sciminer.* TO 'sciminer'@'localhost';
GRANT INDEX ON sciminer.* TO 'sciminer'@'localhost';

-- Additional privileges for administrative features
GRANT ALTER, CREATE, DROP ON sciminer.* TO 'sciminer'@'localhost';

-- AVOID these in production:
-- GRANT ALL PRIVILEGES ON *.*  -- Too broad
-- GRANT FILE ON *.*            -- Security risk
-- WITH GRANT OPTION          -- Allows privilege escalation
```

### Additional Security Measures
```bash
# Disable remote root access
sudo mysql -u root -p -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

# Run mysql_secure_installation (interactive security setup)
sudo mysql_secure_installation

# Check for anonymous users
sudo mysql -u root -p -e "SELECT Host, User FROM mysql.user WHERE User='';"
```

### Password Security
- **NEVER** use the example password `124356!@` in production
- Use strong passwords (minimum 12 characters, mix of cases, numbers, symbols)
- Consider using password manager for storing credentials
- Change passwords regularly

### Database Auditing
```sql
-- Enable audit logging (MariaDB 10.4+)
SET GLOBAL audit_log_format = 'JSON';
SET GLOBAL audit_log_policy = 'ALL';

-- Check audit log
SELECT * FROM mysql.audit_log ORDER BY event_time DESC LIMIT 10;
```

# Additional Resources

- [MariaDB Official Documentation](https://mariadb.com/kb/en/)
- [MySQL to MariaDB Migration Guide](https://mariadb.com/kb/en/migration-from-mysql-to-mariadb/)
- [MariaDB vs MySQL Comparison](https://mariadb.com/kb/en/mariadb-vs-mysql-compatibility/)
- [MariaDB Security Guide](https://mariadb.com/kb/en/securing-mariadb/)
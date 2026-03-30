# SciMiner Production Security Checklist

## ⚠️ CRITICAL SECURITY ACTIONS

These MUST be completed before deploying SciMiner to production:

### Database Security

#### 1. Change All Default Passwords (CRITICAL)
```bash
# Change root password (NOT the example password)
sudo mysql -u root -p
ALTER USER 'root'@'localhost' IDENTIFIED BY 'YOUR_STRONG_PASSWORD_HERE';
FLUSH PRIVILEGES;

# Change sciminer password
ALTER USER 'sciminer'@'localhost' IDENTIFIED BY 'YOUR_STRONG_PASSWORD_HERE';
FLUSH PRIVILEGES;
```

#### 2. Limit Sciminer User Privileges (CRITICAL)
```sql
-- Drop existing sciminer user if it has too broad privileges
DROP USER IF EXISTS 'sciminer'@'localhost';

-- Create new sciminer user with limited privileges
CREATE USER 'sciminer'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';

-- Grant ONLY necessary privileges to sciminer database
GRANT SELECT, INSERT, UPDATE, DELETE ON sciminer.* TO 'sciminer'@'localhost';
GRANT CREATE, ALTER, DROP, INDEX ON sciminer.* TO 'sciminer'@'localhost';
GRANT CREATE TEMPORARY TABLES ON sciminer.* TO 'sciminer'@'localhost;

-- DO NOT GRANT these in production:
-- ❌ GRANT ALL PRIVILEGES ON *.*
-- ❌ GRANT FILE ON *.*
-- ❌ WITH GRANT OPTION

FLUSH PRIVILEGES;
```

#### 3. Secure MariaDB Installation
```bash
# Run MariaDB security script
sudo mysql_secure_installation

# Answer YES to all security questions:
# - Set root password? YES
# - Remove anonymous users? YES
# - Disallow root login remotely? YES
# - Remove test database? YES
# - Reload privilege tables? YES
```

#### 4. Disable Remote Root Access
```bash
sudo mysql -u root -p -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"
```

### Application Security

#### 5. Update Configuration Files
```bash
# Update annotationENV.ini
# NEVER commit passwords to version control!
# Use environment variables instead

# Update /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini:
# - Set strong passwords
# - Update AdminEmail to actual admin email
# - Update Institution name
```

#### 6. Secure File Permissions
```bash
# Secure configuration files
chmod 600 /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini

# Secure web files
chmod 755 /home/sciminer/web
find /home/sciminer/web/html -name "*.cgi" -exec chmod 755 {} \;
find /home/sciminer/web/html -name "*.pm" -exec chmod 644 {} \;

# Secure logs
chmod 644 /var/log/apache2/*.log
```

#### 7. Apache Security
```bash
# Hide Apache version
echo "ServerTokens Prod" | sudo tee -a /etc/apache2/apache2.conf
echo "ServerSignature Off" | sudo tee -a /etc/apache2/apache2.conf

# Disable unnecessary modules
sudo a2dismod status autoindex info

# Restart Apache
sudo systemctl restart apache2
```

## 🔒 SECURITY VALIDATION CHECKS

### Database Security Verification

#### Verify User Privileges
```sql
-- Check current users
SELECT User, Host, Super_priv FROM mysql.user;

-- Check sciminer user privileges
SHOW GRANTS FOR 'sciminer'@'localhost';

-- Verify sciminer cannot access other databases
SHOW DATABASES;  -- Should NOT show all databases as sciminer user
```

#### Test Privilege Restrictions
```bash
# Test as sciminer user
mysql -u sciminer -p -e "SHOW DATABASES;" | wc -l
# Should show limited databases (probably 3: information_schema, performance_schema, sciminer)

# Try to access mysql database (should fail)
mysql -u sciminer -p -e "SELECT * FROM mysql.user;" 2>&1 | grep -i "denied"
# Should return "Access denied"
```

### Web Application Security

#### Check for Information Disclosure
```bash
# Test if server info is exposed
curl -I http://localhost:8888/ 2>&1 | grep -i "server"

# Test error pages
curl http://localhost:8888/nonexistent 2>&1 | grep -i "apache"
```

#### Verify SSL/TLS (when implemented)
```bash
# Check if SSL is properly configured
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -dates
```

## 📋 PRE-DEPLOYMENT CHECKLIST

### Database Setup
- [ ] **Strong root password set** (not example password)
- [ ] **Sciminer user created with LIMITED privileges**
- [ ] **Sciminer user restricted to sciminer database only**
- [ ] **Grant option removed from sciminer user**
- [ ] **Anonymous users removed**
- [ ] **Remote root access disabled**
- [ ] **Test database restored and working**
- [ ] **Backup procedures tested**

### Application Setup
- [ ] **All default passwords changed**
- [ ] **Configuration files secured (600 permissions)**
- [ ] **Admin email updated**
- [ ] **Institution name updated**
- [ ] **Debug mode disabled in production**
- [ ] **Error logging configured**
- [ ] **File permissions properly set**

### Web Server Security
- [ ] **Apache security headers configured**
- [ ] **Server tokens hidden**
- [ ] **Unnecessary modules disabled**
- [ ] **Access logs enabled**
- [ ] **Error logs monitored**
- [ ] **Firewall configured**

### Network Security
- [ ] **Database port 3306 closed to external access**
- [ ] **Only web ports (80/443, 8888) open**
- [ ] **SSL/TLS certificate installed** (if using HTTPS)
- [ ] **Intrusion detection system configured** (optional)

## 🚨 PRODUCTION MONITORING

### Database Monitoring
```sql
-- Enable query logging for monitoring
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/log/mysql/general.log';

-- Monitor slow queries
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
```

### Log Monitoring
```bash
# Monitor Apache logs
tail -f /var/log/apache2/access.log | grep -v "robots.txt"
tail -f /var/log/apache2/error.log

# Monitor MariaDB logs
tail -f /var/log/mysql/error.log
```

## 🔄 SECURITY MAINTENANCE

### Monthly Tasks
- [ ] Review all user privileges
- [ ] Check for suspicious database activity
- [ ] Review error logs for unusual patterns
- [ ] Update MariaDB if security patches available
- [ ] Audit file permissions
- [ ] Verify backup integrity

### Quarterly Tasks
- [ ] Change database passwords (rotate)
- [ ] Security audit of application code
- [ ] Penetration testing (if applicable)
- [ ] Update all system packages
- [ ] Review and update security policies

## 📞 CONTACT INFORMATION

### Security Issues
- For security vulnerabilities: security@yourdomain.com
- For database issues: db-admin@yourdomain.com
- For application issues: sciminer-admin@yourdomain.com

### Emergency Contacts
- Database Administrator: [Phone Number]
- System Administrator: [Phone Number]
- Security Team: [Phone Number]

## 🔐 IMPORTANT NOTES

1. **NEVER commit passwords** to version control
2. **Use environment variables** for sensitive configuration
3. **Regular backups** are essential
4. **Monitor logs** for unusual activity
5. **Keep systems updated** with security patches
6. **Limit access** to only what's necessary
7. **Document all changes** for audit trail

## ✅ DEPLOYMENT SIGN-OFF

Before deploying to production, ensure:

- [ ] All security items in this checklist are completed
- [ ] Security team has reviewed the setup
- [ ] Backup and recovery procedures are tested
- [ ] Monitoring is configured and tested
- [ ] Emergency contact list is updated
- [ ] All documentation is up to date

---

**Remember: Security is an ongoing process, not a one-time setup!**

Last Updated: $(date)
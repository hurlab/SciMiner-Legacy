# SciMiner Installation Scripts Testing Checklist

## Pre-Test Preparation

### 1. Create Backup
```bash
./BACKUP_BEFORE_TEST.sh
```

### 2. Note Current Status
- Apache version: `apache2 -v`
- MariaDB version: `mysql --version`
- Perl version: `perl --version`
- Web interface: `curl http://localhost:8888/SciMiner/`
- Perl modules: `./check_system_perl_modules.pl`

## Test Stage 1: SETUP_INFRASTRUCTURE.sh

### Expected Behavior:
1. Should detect existing Apache and MariaDB
2. Should ask if you want to reinstall/reconfigure
3. Should offer to keep existing installation
4. Should create database 'sciminer' if not exists
5. Should create user 'sciminer' if not exists
6. Should import sciminer.sql if available
7. Should configure Apache virtual host

### Test Commands:
```bash
# Run the script (as root or with sudo)
sudo ./SETUP_INFRASTRUCTURE.sh

# At prompts, choose to:
- Keep existing Apache (select N or press Enter)
- Keep existing MariaDB (select N or press Enter)
- Continue with existing database (select Y)
```

### What to Watch For:
- Script should detect existing installations
- Should ask for confirmation before making changes
- Should create backups of configurations
- Should not break existing functionality

## Test Stage 2: INSTALL_PERL_MODULES.sh

### Expected Behavior:
1. Should verify infrastructure is ready
2. Should install build tools
3. Should install available system packages
4. Should install missing modules via CPAN
5. Should fix Boulder::Medline syntax if present
6. Should update CGI scripts to use system Perl
7. Should run verification tests

### Test Commands:
```bash
# Run the script (as root or with sudo)
sudo ./INSTALL_PERL_MODULES.sh
```

### What to Watch For:
- Should skip already installed modules
- Should handle package availability gracefully
- Should not overwrite existing fixes
- Should complete without errors

## Post-Test Verification

### 1. Check Apache
```bash
sudo systemctl status apache2
curl http://localhost:8888/
```

### 2. Check Database
```bash
mysql -u sciminer -p sciminer
SHOW DATABASES;
SHOW TABLES;
```

### 3. Check Perl Modules
```bash
./check_system_perl_modules.pl
```

### 4. Check SciMiner
```bash
curl http://localhost:8888/SciMiner/
```

### 5. Check Error Logs
```bash
sudo tail /var/log/apache2/sciminer_error.log
```

## If Something Goes Wrong

### Restore from Backup:
```bash
# Restore Apache config
sudo cp /home/sciminer/backup_before_test_*/sciminer.conf.backup /etc/apache2/sites-available/sciminer.conf
sudo systemctl reload apache2

# Restore SciMiner config
cp /home/sciminer/backup_before_test_*/annotationENV.ini.backup /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini

# Restore Boulder::Medline if needed
sudo cp /home/sciminer/backup_before_test_*/Boulder_Medline.pm.backup /usr/local/share/perl/5.38.2/Boulder/Medline.pm
```

### Common Issues and Solutions:
1. **Apache fails to start**: Check configuration syntax
2. **Database connection fails**: Verify credentials
3. **CGI scripts return 500**: Check error logs
4. **Missing modules**: Run `sudo cpanm Module::Name`

## Test Results to Document

### Stage 1 Results:
- [ ] Detected existing Apache correctly
- [ ] Prompted for confirmation
- [ ] Created database/user successfully
- [ ] Configured Apache without breaking existing setup
- [ ] Any error messages: _______________

### Stage 2 Results:
- [ ] Verified infrastructure correctly
- [ ] Installed/verified all modules
- [ ] Fixed Boulder::Medline without issues
- [ ] Updated CGI scripts
- [ ] Any error messages: _______________

### Final Verification:
- [ ] SciMiner web interface works
- [ ] All Perl modules installed
- [ ] No errors in logs
- [ ] Overall success: Yes/No

## Notes

Document any issues, suggestions for improvements, or unexpected behavior during testing.
# PERMISSIONS FIX REQUIRED

The "Forbidden" error occurs because Apache (running as www-data user) cannot access files in your home directory.

## QUICK FIX (run these commands):

```bash
# Fix home directory permissions
chmod 755 /home/sciminer

# Fix web directory permissions
chmod -R 755 /home/sciminer/web

# Make CGI scripts executable
find /home/sciminer/web/html -name "*.cgi" -exec chmod +x {} \;
find /home/sciminer/web/html -name "*.pl" -exec chmod +x {} \;

# Restart Apache
sudo systemctl restart apache2
```

## Or run the quick fix script:

```bash
bash /home/sciminer/web/quick_fix.sh
sudo systemctl restart apache2
```

## For a more secure solution:

Run the comprehensive fix script:
```bash
bash /home/sciminer/web/fix_permissions.sh
```

This gives you options:
1. Make home directory accessible (less secure but simple)
2. Add www-data to sciminer group (recommended)
3. Move files to /var/www/ (most secure)

## After fixing permissions:

- Access SciMiner at: http://localhost:8888/SciMiner/
- Test CGI at: http://localhost:8888/test_cgi.cgi

If you still get errors, check Apache logs:
```bash
tail -f /var/log/apache2/sciminer_error.log
```
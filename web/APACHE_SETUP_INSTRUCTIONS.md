# Apache HTTP Server Setup for SciMiner

## Quick Setup Instructions

Run these commands to configure Apache for SciMiner:

```bash
# 1. Run the setup script (requires sudo)
sudo bash /home/sciminer/web/setup_apache.sh

# 2. If the script fails, run these manually:
sudo a2enmod cgi alias env reqtimeout
sudo a2dissite 000-default
sudo a2ensite sciminer
sudo systemctl restart apache2
```

## What the setup does:

1. Enables required Apache modules (CGI, alias, env, reqtimeout)
2. Creates a virtual host configuration for SciMiner on port 8888
3. Sets the document root to `/home/sciminer/web/html`
4. Configures CGI script execution for `.cgi` and `.pl` files
5. Sets environment variables for Perl module paths
6. Updates Apache to listen on port 8888
7. Sets appropriate file permissions

## After Setup

Access SciMiner at:
- Main page: http://localhost:8888/SciMiner/
- Test CGI: http://localhost:8888/test_cgi.cgi

## Troubleshooting

If you encounter issues:

1. Check Apache error logs:
   ```bash
   tail -f /var/log/apache2/sciminer_error.log
   ```

2. Check Apache access logs:
   ```bash
   tail -f /var/log/apache2/sciminer_access.log
   ```

3. Verify Apache is running on the correct port:
   ```bash
   sudo netstat -tlnp | grep :8888
   ```

4. Test Apache configuration:
   ```bash
   sudo apache2ctl configtest
   ```

5. Restart Apache if needed:
   ```bash
   sudo systemctl restart apache2
   ```

## Manual Configuration Files (for reference)

- Site config: `/etc/apache2/sites-available/sciminer.conf`
- Ports config: `/etc/apache2/ports.conf`
- Apache logs: `/var/log/apache2/sciminer_*.log`
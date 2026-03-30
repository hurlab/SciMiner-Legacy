#!/bin/bash
# Backup current configurations before testing new scripts

echo "Creating backups before testing..."

# Create backup directory
BACKUP_DIR="/home/sciminer/backup_before_test_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"

# Backup Apache configuration
if [ -f /etc/apache2/sites-available/sciminer.conf ]; then
    cp /etc/apache2/sites-available/sciminer.conf "$BACKUP_DIR/sciminer.conf.backup"
    echo "✓ Apache configuration backed up"
fi

# Backup SciMiner configuration
if [ -f /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini ]; then
    cp /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini "$BACKUP_DIR/annotationENV.ini.backup"
    echo "✓ SciMiner configuration backed up"
fi

# Backup Boulder::Medline (if fixed)
if [ -f /usr/local/share/perl/5.38.2/Boulder/Medline.pm ]; then
    cp /usr/local/share/perl/5.38.2/Boulder/Medline.pm "$BACKUP_DIR/Boulder_Medline.pm.backup"
    echo "✓ Boulder::Medline backed up"
fi

# List current Perl modules (for comparison)
/home/sciminer/check_system_perl_modules.pl > "$BACKUP_DIR/perl_modules_before.txt"
echo "✓ Perl module list saved"

echo ""
echo "Backup complete!"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "To restore if needed:"
echo "  Apache: sudo cp $BACKUP_DIR/sciminer.conf.backup /etc/apache2/sites-available/sciminer.conf"
echo "  Config: cp $BACKUP_DIR/annotationENV.ini.backup /home/sciminer/ANNOTATION/SciMinerDB/annotationENV.ini"
echo "  Boulder::Medline: sudo cp $BACKUP_DIR/Boulder_Medline.pm.backup /usr/local/share/perl/5.38.2/Boulder/Medline.pm"
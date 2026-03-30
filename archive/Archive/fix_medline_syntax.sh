#!/bin/bash
# Fix syntax error in Boulder::Medline module

echo "Fixing syntax error in Boulder::Medline.pm..."

# Backup the original file
sudo cp /usr/local/share/perl/5.38.2/Boulder/Medline.pm /usr/local/share/perl/5.38.2/Boulder/Medline.pm.backup

# Fix the syntax error on line 274
sudo sed -i 's/$line=@recordlines\[$i\];/$line=$recordlines[$i];/' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

# Verify the fix
echo ""
echo "Checking the fix..."
sudo sed -n '270,280p' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

echo ""
echo "Syntax fixed successfully!"
echo "Original file backed up to: Medline.pm.backup"
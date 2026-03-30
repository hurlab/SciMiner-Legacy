#!/bin/bash
# Complete fix for Boulder::Medline syntax errors

echo "Fixing Boulder::Medline syntax errors..."

# Backup the original file
sudo cp /usr/local/share/perl/5.38.2/Boulder/Medline.pm /usr/local/share/perl/5.38.2/Boulder/Medline.pm.backup.$(date +%Y%m%d_%H%M%S)

# Fix 1: Correct array access syntax on line 274
# Change $line=@recordlines[$i]; to $line=$recordlines[$i];
sudo sed -i '274s/@recordlines\[$i\]/$recordlines[$i]/' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

# Fix 2: Add missing 'my' declaration for $i variable
# Change for ($i=0; ... to for (my $i=0; ...
sudo sed -i '273s/for (\$i=/for (my $i=/' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

# Fix 3: Add missing declaration for $junk and other variables
# Add my($junk, $ui, $da, $pmid, $ad, $so); after line 263
sudo sed -i '263a my($junk, $ui, $da, $pmid, $ad, $so);' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

echo ""
echo "Checking the fixes..."
echo "Line 263-280 now reads:"
sed -n '263,280p' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

echo ""
echo "Checking Perl syntax..."
if perl -c /usr/local/share/perl/5.38.2/Boulder/Medline.pm 2>/dev/null; then
    echo "✓ Syntax is now valid!"
else
    echo "✗ Syntax errors still exist. Please check manually."
fi

echo ""
echo "Fixes completed!"
echo "Original file backed up with timestamp."
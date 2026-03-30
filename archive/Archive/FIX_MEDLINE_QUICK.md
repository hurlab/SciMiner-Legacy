# Quick Fix for Boulder::Medline Syntax Errors

## Issues Found:
1. Line 274: `$line=@recordlines[$i];` - Incorrect array access syntax
2. Line 273: Missing `my` declaration for `$i` variable
3. Line 273: Missing declarations for `$junk`, `$ui`, `$da`, `$pmid`, `$ad`, `$so`

## Quick Fix Commands:

Run these commands as root or with sudo:

```bash
# Backup the file first
cp /usr/local/share/perl/5.38.2/Boulder/Medline.pm /usr/local/share/perl/5.38.2/Boulder/Medline.pm.backup

# Fix array access syntax (line 274)
sed -i 's/$line=@recordlines\[$i\];/$line=$recordlines[$i];/' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

# Add missing 'my' for $i (line 273)
sed -i 's/for (\$i=/for (my $i=/' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

# Add missing variable declarations (after line 263)
sed -i '263a my($junk, $ui, $da, $pmid, $ad, $so);' /usr/local/share/perl/5.38.2/Boulder/Medline.pm

# Check syntax
perl -c /usr/local/share/perl/5.38.2/Boulder/Medline.pm
```

## Or run the complete fix script:
```bash
sudo ./medline_fix_complete.sh
```

## Expected Result:
Line 274 should change from:
```perl
$line=@recordlines[$i];
```
to:
```perl
$line=$recordlines[$i];
```

And line 273 should change from:
```perl
for ($i=0; $i<=$#recordlines; $i++) {
```
to:
```perl
for (my $i=0; $i<=$#recordlines; $i++) {
```

This will fix the syntax errors and make the module work correctly with SciMiner.
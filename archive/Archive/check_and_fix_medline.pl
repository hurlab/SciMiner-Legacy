#!/usr/bin/perl
# Check and fix syntax errors in Boulder::Medline module

use strict;
use warnings;

my $file = '/usr/local/share/perl/5.38.2/Boulder/Medline.pm';
my $backup = $file . '.backup_' . time;

print "Checking Boulder::Medline for syntax issues...\n";

# Read the file
open my $fh, '<', $file or die "Cannot read $file: $!";
my @lines = <$fh>;
close $fh;

# Find issues
my @issues;
for my $i (0..$#lines) {
    my $line_num = $i + 1;
    my $line = $lines[$i];

    # Check for @array[index] pattern (incorrect syntax)
    if ($line =~ /@\w+\[\s*\$\w+\s*\]/) {
        push @issues, {
            line => $line_num,
            type => 'array_syntax',
            text => $line,
            fixed => $line
        };
        # Fix the syntax
        $lines[$i] =~ s/@(\w+)\[\s*(\$\w+)\s*\]/\$$1[$2]/g;
    }
}

# Report findings
if (@issues) {
    print "\nFound " . scalar(@issues) . " syntax issue(s):\n";
    foreach my $issue (@issues) {
        print "  Line $issue->{line}: $issue->{type}\n";
        print "    Original: $issue->{text}";
    }

    # Create backup
    print "\nCreating backup: $backup\n";
    open my $backup_fh, '>', $backup or die "Cannot create backup: $!";
    print $backup_fh join('', @lines);
    close $backup_fh;

    # Fix the file
    print "Fixing syntax errors...\n";
    open my $out_fh, '>', $file or die "Cannot write to $file: $!";
    print $out_fh join('', @lines);
    close $out_fh;

    print "\nSyntax fixes applied successfully!\n";
} else {
    print "No syntax issues found.\n";
}

# Check Perl syntax
print "\nChecking Perl syntax...\n";
my $result = system("perl -c $file 2>&1");
if ($result == 0) {
    print "✓ Syntax is valid!\n";
} else {
    print "✗ Syntax errors still exist.\n";
}

# Show the specific line that was reported
print "\nShowing lines 270-280:\n";
open $fh, '<', $file or die "Cannot read $file: $!";
my @all_lines = <$fh>;
close $fh;

for my $i (269..279) {
    last if $i >= @all_lines;
    my $line_num = $i + 1;
    print sprintf("%3d: %s", $line_num, $all_lines[$i]);
}
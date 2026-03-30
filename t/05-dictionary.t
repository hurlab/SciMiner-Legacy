#!/usr/bin/env perl
################################################################################
#
#   05-dictionary.t - Dictionary File Format Validation
#
#   Verify that dictionary files used by SciMiner have the expected
#   tab-delimited format and column counts.
#   Tests are skipped if dictionary files do not exist.
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);

use Test::More;

my $dict_dir = "$RealBin/../annotation/SciMinerDB/Work/Dictionary";

if (! -d $dict_dir) {
    plan skip_all => "Dictionary directory not found: $dict_dir";
}

# Dictionary files to validate
my @dict_files = (
    {
        name        => 'HUGO_trimmed_final_default',
        min_columns => 5,   # tab-delimited, at least 5 columns
        min_lines   => 100, # should have thousands of genes
    },
    {
        name        => 'UNIQUENAME_default',
        min_columns => 3,   # 3 columns: name, ID, source
        min_lines   => 100,
    },
    {
        name        => 'UNIQUESYMBOL_default',
        min_columns => 3,   # 3 columns: symbol, ID, source
        min_lines   => 100,
    },
);

# Count tests: existence + format + min lines per file
my $test_count = 0;
my @available;
foreach my $dict (@dict_files) {
    my $file = "$dict_dir/$dict->{name}";
    if (-f $file) {
        $test_count += 4;  # exists, non-empty, column count, line count
        push @available, $dict;
    }
}

if ($test_count == 0) {
    plan skip_all => 'No dictionary files found -- skipping dictionary tests';
} else {
    plan tests => $test_count;
}

foreach my $dict (@available) {
    my $file = "$dict_dir/$dict->{name}";
    my $name = $dict->{name};

    ok(-f $file, "$name: file exists");
    ok(-s $file, "$name: file is non-empty");

    # Check column count of first data line
    open my $fh, '<', $file or do {
        fail("$name: cannot open file: $!");
        fail("$name: (skipping column check)");
        next;
    };

    my $first_line = <$fh>;
    chomp $first_line if defined $first_line;

    if (defined $first_line) {
        my @cols = split(/\t/, $first_line);
        cmp_ok(scalar @cols, '>=', $dict->{min_columns},
               "$name: first line has >= $dict->{min_columns} tab-delimited columns (found " . scalar(@cols) . ")");
    } else {
        fail("$name: file appears empty");
    }

    # Count lines
    my $line_count = 1;  # already read first line
    while (<$fh>) { $line_count++; }
    close $fh;

    cmp_ok($line_count, '>=', $dict->{min_lines},
           "$name: has >= $dict->{min_lines} lines (found $line_count)");
}

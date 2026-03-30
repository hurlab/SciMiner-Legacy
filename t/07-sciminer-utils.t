#!/usr/bin/env perl
################################################################################
#
#   07-sciminer-utils.t - SciMiner.pm Utility Function Tests
#
#   Test utility functions from SciMiner.pm:
#     - is_number()
#     - special_character_handling_for_hash_key()
#     - braket_character_replaced_by_space()
#     - first_chr_keep_upper_other_lower_case()
#     - get_file_size_in_human_readable_format()
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More tests => 15;
use File::Temp qw(tempfile);

# Set environment for module loading
$ENV{SCIMINER_HOME} = "$RealBin/..";

# Load the modules
do "$RealBin/../annotation/SciMinerDB/Modules/Annotation/basicIO.pm";
do "$RealBin/../annotation/SciMinerDB/Modules/Annotation/SciMiner.pm";
ok(!$@, 'SciMiner.pm loaded') or BAIL_OUT("Cannot load SciMiner.pm: $@");

# ==========================================================================
# is_number()
# ==========================================================================
subtest 'is_number with integers' => sub {
    plan tests => 4;
    is(is_number('42'),   1, '42 is a number');
    is(is_number('0'),    1, '0 is a number');
    is(is_number('-7'),   1, '-7 is a number');
    is(is_number('1000'), 1, '1000 is a number');
};

subtest 'is_number with floats' => sub {
    plan tests => 3;
    is(is_number('3.14'),   1, '3.14 is a number');
    is(is_number('-0.001'), 1, '-0.001 is a number');
    is(is_number('1e10'),   1, '1e10 is a number (scientific notation)');
};

subtest 'is_number with non-numbers' => sub {
    plan tests => 4;
    is(is_number('hello'),  0, '"hello" is not a number');
    is(is_number('12abc'),  0, '"12abc" is not a number');
    is(is_number(''),       0, 'empty string is not a number');
    is(is_number('abc123'), 0, '"abc123" is not a number');
};

subtest 'is_number with whitespace' => sub {
    plan tests => 2;
    is(is_number('  42  '), 1, '"  42  " is a number (leading/trailing spaces)');
    is(is_number('  '),     0, '"  " (spaces only) is not a number');
};

# ==========================================================================
# special_character_handling_for_hash_key()
# ==========================================================================
subtest 'special_character_handling_for_hash_key' => sub {
    plan tests => 5;

    my $result1 = special_character_handling_for_hash_key('test+value');
    like($result1, qr/\\\+/, 'Plus sign is escaped');

    my $result2 = special_character_handling_for_hash_key('gene(name)');
    like($result2, qr/\\\(/, 'Opening parenthesis is escaped');
    like($result2, qr/\\\)/, 'Closing parenthesis is escaped');

    my $result3 = special_character_handling_for_hash_key('test.value');
    like($result3, qr/\\\./, 'Period is escaped');

    my $result4 = special_character_handling_for_hash_key('no_special');
    is($result4, 'no_special', 'String without special chars is unchanged');
};

# ==========================================================================
# braket_character_replaced_by_space()
# ==========================================================================
subtest 'braket_character_replaced_by_space' => sub {
    plan tests => 4;

    my $r1 = braket_character_replaced_by_space('gene(name)');
    like($r1, qr/gene\s+name\s*/, 'Parentheses replaced by spaces');

    my $r2 = braket_character_replaced_by_space('array[index]');
    like($r2, qr/array\s+index\s*/, 'Square brackets replaced by spaces');

    my $r3 = braket_character_replaced_by_space('a+b?c!d');
    unlike($r3, qr/[+?!]/, 'Special chars +?! replaced by spaces');

    my $r4 = braket_character_replaced_by_space('simple text');
    is($r4, 'simple text', 'Simple text is unchanged');
};

# ==========================================================================
# first_chr_keep_upper_other_lower_case()
# ==========================================================================
subtest 'first_chr_keep_upper_other_lower_case' => sub {
    plan tests => 4;

    is(first_chr_keep_upper_other_lower_case('HELLO'),
       'Hello', 'HELLO becomes Hello');

    is(first_chr_keep_upper_other_lower_case('hello'),
       'hello', 'hello stays hello');

    is(first_chr_keep_upper_other_lower_case('BRCA1'),
       'Brca1', 'BRCA1 becomes Brca1');

    is(first_chr_keep_upper_other_lower_case('A'),
       'A', 'Single character A stays A');
};

# ==========================================================================
# get_file_size_in_human_readable_format()
# ==========================================================================
subtest 'get_file_size_in_human_readable_format - non-existent file' => sub {
    plan tests => 1;
    is(get_file_size_in_human_readable_format('/tmp/nonexistent_sciminer_test_file_xyz'),
       '0B', 'Non-existent file returns 0B');
};

subtest 'get_file_size_in_human_readable_format - small file' => sub {
    plan tests => 1;
    # Create a small temp file (< 1KB)
    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh "Hello, World!";
    close $fh;

    my $result = get_file_size_in_human_readable_format($filename);
    like($result, qr/^\d+B$/, "Small file returns size in bytes (got: $result)");
};

subtest 'get_file_size_in_human_readable_format - KB file' => sub {
    plan tests => 1;
    # Create a ~2KB temp file
    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh 'x' x 2048;
    close $fh;

    my $result = get_file_size_in_human_readable_format($filename);
    like($result, qr/^\d+KB$/, "2KB file returns size in KB (got: $result)");
};

subtest 'get_file_size_in_human_readable_format - MB file' => sub {
    plan tests => 1;
    # Create a ~1.5MB temp file
    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh 'x' x (1024 * 1024 + 512 * 1024);
    close $fh;

    my $result = get_file_size_in_human_readable_format($filename);
    like($result, qr/^\d+MB$/, "1.5MB file returns size in MB (got: $result)");
};

# Additional edge-case tests for utility robustness

subtest 'is_number edge cases' => sub {
    plan tests => 3;
    is(is_number('+5'),     1, '"+5" is a number');
    is(is_number('0.0'),    1, '"0.0" is a number');
    is(is_number('-1e-3'),  1, '"-1e-3" is a number');
};

subtest 'special chars comprehensive' => sub {
    plan tests => 3;
    my $r = special_character_handling_for_hash_key('$var@list#tag');
    like($r, qr/\\\$/, 'Dollar sign is escaped');
    like($r, qr/\\\@/, 'At sign is escaped');
    like($r, qr/\\\#/, 'Hash sign is escaped');
};

subtest 'braket with pipe and colon' => sub {
    plan tests => 2;
    my $r = braket_character_replaced_by_space('a|b/c;d:e');
    unlike($r, qr/[|\/;:]/, 'Pipe, slash, semicolon, colon are replaced');
    like($r, qr/a\s+b\s+c\s+d\s+e/, 'Characters replaced by spaces');
};

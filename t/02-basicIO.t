#!/usr/bin/env perl
################################################################################
#
#   02-basicIO.t - Basic I/O Function Tests
#
#   Test utility functions from basicIO.pm:
#     - shortFileNameExtraction()
#     - shortFileNameExtractionWOExt()
#     - fileExtensionRemovalForSingleFile()
#     - get_current_time_full()
#     - get_current_time_short()
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More tests => 13;

# Load basicIO.pm (it has no package declaration, so functions go into main::)
$ENV{SCIMINER_HOME} = "$RealBin/..";
do "$RealBin/../annotation/SciMinerDB/Modules/Annotation/basicIO.pm";
ok(!$@, 'basicIO.pm loaded') or BAIL_OUT("Cannot load basicIO.pm: $@");

# --------------------------------------------------------------------------
# shortFileNameExtraction
# --------------------------------------------------------------------------
{
    my @full = ('/home/user/documents/report.pdf',
                '/var/log/system.log',
                '/tmp/data.csv');
    my @short = shortFileNameExtraction(\@full);

    is(scalar @short, 3, 'shortFileNameExtraction returns correct count');
    is($short[0], 'report.pdf', 'shortFileNameExtraction extracts filename with ext');
    is($short[1], 'system.log', 'shortFileNameExtraction extracts second filename');
    is($short[2], 'data.csv',   'shortFileNameExtraction extracts third filename');
}

# --------------------------------------------------------------------------
# shortFileNameExtractionWOExt
# --------------------------------------------------------------------------
{
    my @full = ('/home/user/documents/report.pdf',
                '/var/log/system.log',
                '/tmp/archive.tar.gz');
    my @short = shortFileNameExtractionWOExt(\@full);

    is(scalar @short, 3, 'shortFileNameExtractionWOExt returns correct count');
    is($short[0], 'report', 'shortFileNameExtractionWOExt removes .pdf extension');
    is($short[1], 'system', 'shortFileNameExtractionWOExt removes .log extension');
    # For multi-dot files, it removes only the last extension
    is($short[2], 'archive.tar', 'shortFileNameExtractionWOExt removes last extension only');
}

# --------------------------------------------------------------------------
# fileExtensionRemovalForSingleFile
# --------------------------------------------------------------------------
{
    my $result = fileExtensionRemovalForSingleFile('report.pdf');
    is($result, 'report', 'fileExtensionRemovalForSingleFile removes .pdf');

    my $result2 = fileExtensionRemovalForSingleFile('archive.tar.gz');
    is($result2, 'archive.tar', 'fileExtensionRemovalForSingleFile removes .gz');
}

# --------------------------------------------------------------------------
# get_current_time_full
# --------------------------------------------------------------------------
{
    my $time = get_current_time_full();
    ok(defined $time && $time ne '', 'get_current_time_full returns non-empty string');
    # Expected format: "Mon DD (Day)\tHH:MM:SS"
    like($time, qr/\w{3}\s+\d+\s+\(\w{3}\)/, 'get_current_time_full has expected format');
}

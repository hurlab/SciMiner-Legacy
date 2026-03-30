#!/usr/bin/env perl
################################################################################
#
#   01-config.t - Configuration Loading Tests
#
#   Verify annotationENV.ini loading and required configuration keys.
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More;

# --------------------------------------------------------------------------
# Test 1: Load annotationENV.ini via basicIO::anno_environmental_file_open
# --------------------------------------------------------------------------
my $ini_path = "$RealBin/../annotation/SciMinerDB/annotationENV.ini";

if (! -f $ini_path) {
    plan skip_all => 'annotationENV.ini not found -- skipping config tests';
}

plan tests => 12;

# basicIO.pm does not use a package declaration. We load it with do/require
# and call the function from the main namespace.
{
    # Set environment so basicIO can find the ini file
    $ENV{SCIMINER_HOME} = "$RealBin/..";

    do "$RealBin/../annotation/SciMinerDB/Modules/Annotation/basicIO.pm";
    ok(!$@, 'basicIO.pm loaded without error') or diag($@);
}

my %env = anno_environmental_file_open();

ok(scalar(keys %env) > 0, 'anno_environmental_file_open returned a non-empty hash');

# Required keys from annotationENV.ini
my @required_keys = qw(ANNOPath SciMinerPath SciMinerWebPath DB username MaxDoc MaxNewDoc);

foreach my $key (@required_keys) {
    ok(exists $env{$key} && defined $env{$key} && $env{$key} ne '',
       "Config key '$key' exists and is non-empty (value: " . ($env{$key} // '<undef>') . ")");
}

# Verify specific expected values
like($env{DB}, qr/sciminer/i, 'Database name contains "sciminer"');
like($env{MaxDoc}, qr/^\d+$/, 'MaxDoc is a numeric value');
like($env{MaxNewDoc}, qr/^\d+$/, 'MaxNewDoc is a numeric value');

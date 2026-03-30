#!/usr/bin/env perl
################################################################################
#
#   00-modules.t - Module Loading Tests
#
#   Verify that all core SciMiner Perl modules load without errors.
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More tests => 8;

# Annotation::Config has a known issue: _init_config() is called in a BEGIN
# block before the sub is defined (sub declaration is after the BEGIN block).
# We test compilation separately and note the bug.
{
    my $config_path = "$RealBin/../annotation/SciMinerDB/Modules/Annotation/Config.pm";
    ok(-f $config_path, 'Config.pm file exists');

    # NOTE: Annotation::Config fails to load at runtime due to a sub ordering
    # issue in its BEGIN block. This is a known production bug:
    #   Undefined subroutine &Annotation::Config::_init_config called at Config.pm line 32.
    # The test below documents this failure. Do NOT fix the production code here.
    my $output = `$^X -I"$RealBin/../annotation/SciMinerDB/Modules" -c "$config_path" 2>&1`;
    my $compiles = ($? == 0) ? 1 : 0;
    TODO: {
        local $TODO = 'Config.pm has a known BEGIN/_init_config ordering bug';
        ok($compiles, 'Config.pm compiles without error');
    }
}

# Modules that should load cleanly
use_ok('Annotation::Logger')          or diag('Failed to load Annotation::Logger');
use_ok('Annotation::DBHelper')        or diag('Failed to load Annotation::DBHelper');

# basicIO.pm does not declare a package -- it is loaded via require/do,
# so we test that the file compiles without error.
{
    my $basicIO_path = "$RealBin/../annotation/SciMinerDB/Modules/Annotation/basicIO.pm";
    ok(-f $basicIO_path, 'basicIO.pm file exists');

    my $result = system($^X, '-c', $basicIO_path);
    is($result, 0, 'basicIO.pm compiles without error');
}

# SciMiner.pm is a very large file (32K+ lines). Verify it compiles.
{
    my $sciminer_path = "$RealBin/../annotation/SciMinerDB/Modules/Annotation/SciMiner.pm";
    ok(-f $sciminer_path, 'SciMiner.pm file exists');

    my $result = system($^X,
        "-I$RealBin/../annotation/SciMinerDB/Modules",
        '-c', $sciminer_path);
    is($result, 0, 'SciMiner.pm compiles without error');
}

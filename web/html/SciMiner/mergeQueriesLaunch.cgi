#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

use MinimalAppMergeQueries;

my $webapp = MinimalAppMergeQueries->new();
$webapp->run();



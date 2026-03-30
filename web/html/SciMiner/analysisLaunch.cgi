#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

use MinimalAppAnalysis;

my $webapp = MinimalAppAnalysis->new();
$webapp->run();



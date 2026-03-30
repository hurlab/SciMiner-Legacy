#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

use MinimalAppCompleted;

my $webapp = MinimalAppCompleted->new();
$webapp->run();



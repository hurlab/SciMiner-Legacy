#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

use MinimalAppSciMiner;

my $webapp = MinimalAppSciMiner->new();
$webapp->run();



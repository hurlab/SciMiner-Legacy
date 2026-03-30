#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

# Load required modules
BEGIN {
push (@INC, "/home/sciminer/legacy/annotation/SciMinerDB/Modules/");
push (@INC, "/home/sciminer/legacy/annotation/SciMinerDB/Modules/SciMiner");
push (@INC, "/home/sciminer/legacy/annotation/SciMinerDB/Modules/Annotation");
}

# Use secure application module
use MinimalAppSciMiner_secure;

my $webapp = MinimalAppSciMiner_secure->new();
$webapp->run();
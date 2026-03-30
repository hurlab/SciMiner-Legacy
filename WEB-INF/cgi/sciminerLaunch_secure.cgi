#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

# Load required modules
BEGIN {
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/SciMiner");
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/Annotation");
}

# Use secure application module
use MinimalAppSciMiner_secure;

my $webapp = MinimalAppSciMiner_secure->new();
$webapp->run();
#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerCleaner
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           sciminer @ umich . edu
#
#      
#   Desc: This script will delete records corresponding to the given actualString
#
#############################################################################
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}

use Annotation::basicIO;            
use Annotation::SciMiner;   
use strict;
use warnings;

#  Load working environment for ANNOTATION
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};

#  Database Access Information
my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

#  Connect to MySQL SciMiner Database
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                    return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

#  Check list file
if (not defined $ARGV[0])
{	exit;
}
                    
#  Load pmids to delete
my %termChecks 	= ();
if ((defined $ARGV[0]) && (-f $ARGV[0]))
{   open (FILE, $ARGV[0]);
    while(<FILE>)
    {   my $line        = lc($_);
        $line           =~ s/\r|\n//g;
        $termChecks{$line}	= 1;
        $line			=~ s/-/ /g;
        $termChecks{$line}	= 1;
    }
    close FILE;
}

my @terms 		= keys %termChecks;
my $termCount	= scalar @terms;
my @tmpArray	= ();
my $termString	= '';

for (my $i=0; $i < $termCount; $i+=50)
{	print "! Processing ".($i+1)." th 50 terms...\n";
	my $startIndex	= $i;
	my $endIndex	= $i + 50;
	if ($endIndex > $termCount)
	{	$endIndex	= $termCount;
	}
	@tmpArray		= ();
	
	for (my $j=$startIndex; $j < $endIndex; $j++)
	{	push @tmpArray, $terms[$j];
	}
	$termString		= "'".join ("','", @tmpArray)."'";

	$dbh->do("UPDATE sentence2gene set inExClude=2, inExCludeCond=\"UserEdit\", editTag = 1, editUser = 1 WHERE actualString in ($termString)") || print STDERR "!Can't update from sentence2gene";	
}

exit;

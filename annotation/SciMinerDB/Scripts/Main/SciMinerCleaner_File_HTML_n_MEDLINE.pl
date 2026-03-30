#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerCleaner_File_HTML_n_MEDLINE
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           juhur @ umich . edu
#
#      
#   Desc: This script will delete records corresponding to the given PMIDs
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

#  Setting variables
my $sleepInterval = 10;     # 60 seconds

#  Load pmids to delete
my @PMIDs = ();
if ((defined $ARGV[0]) && (-f $ARGV[0]))
{   open (FILE, $ARGV[0]);
    while(<FILE>)
    {   my $line        = $_;
        $line           =~ s/\r|\n//g;
        my @tmpSplit    = split (/\t/, $line);
        if ((defined $tmpSplit[0]) && ($tmpSplit[0] ne ""))
        {   push @PMIDs, $tmpSplit[0];
        }
    }
    close FILE;
}

#  Create a merged string 
if (not defined $PMIDs[0])
{   die "! There is no PMID to process\n";
}

my $totalDoc		= scalar @PMIDs;
my $failedHTML		= 0;
my $failedMEDLINE 	= 0;

foreach my $pmid (@PMIDs)
{   	print "rm -Rf $annoENV{SciMinerPath}/CorpusData/Original/$pmid.html\n";
        `rm -Rf $annoENV{SciMinerPath}/CorpusData/Original/$pmid.html` || $failedHTML++;
	    `rm -Rf $annoENV{SciMinerPath}/CorpusData/Original/$pmid.medline` || $failedMEDLINE++;
}

print "Total document in the list:\t$totalDoc\n";
print "HTML not deleted:\t$failedHTML\n";
print "MEDLINE not deleted:\t$failedMEDLINE\n";
exit;

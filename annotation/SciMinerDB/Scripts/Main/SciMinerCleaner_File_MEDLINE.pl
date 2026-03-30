#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerCleaner_File_MEDLINE
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           juhur @ umich . edu
#
#      
#   Desc: This script will delete the MEDLINE files specified by 
#			a file of PMID list.
#
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
}elsif ((defined $ARGV[0]) && ($ARGV[0] !~ /\D/))
{   foreach my $pmid (@ARGV)
	{   if ((defined $pmid) && ($pmid !~ /\D/))
		{   push @PMIDs, $pmid;
		}
	}
}

#  Create a merged string 
if (not defined $PMIDs[0])
{   die "! There is no PMID to process\n";
}


foreach my $pmid (@PMIDs)
{	print "Deleting $annoENV{SciMinerPath}/CorpusData/Original/$pmid.medline\n";
	unlink ("$annoENV{SciMinerPath}/CorpusData/Original/$pmid.medline");
}




exit;

#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerCleaner
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
my $pmidString  = join (',', @PMIDs);


#  Connect to MySQL SciMiner Database
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                    return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

#  Delete records from document table
print "! Deleting records from document table\n";
$dbh->do("DELETE FROM document WHERE pmid in ($pmidString)") || print STDERR "!Can't delete from document";

#  Delete records from docmesh table
print "! Deleting records from docmesh table\n";
$dbh->do("DELETE FROM docmesh WHERE pmid in ($pmidString)") || print STDERR "!Can't delete from docmesh";

#  Delete records from sentence table
print "! Deleting records from sentence table\n";
$dbh->do("DELETE FROM sentence WHERE pmid in ($pmidString)") || print STDERR "!Can't delete from sentence";

#  Delete records from sentence2gene table
print "! Deleting records from sentence2gene table\n";
$dbh->do("DELETE FROM sentence2gene WHERE pmid in ($pmidString)") || print STDERR "!Can't delete from sentence2gene";

exit;

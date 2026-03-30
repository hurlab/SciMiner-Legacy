#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerDB_Content_Extract
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           sciminer @ umich . edu
#
#      
#   Desc: 	This script will extract SciMiner contents for 
#			a given list of PMIDs. Extracted contents can be 
#			entered into another SciMiner server by SciMinerDB_Content_Insert_v2.pl
#
#	Usage:  >ThisScript.pl [PMID File] <OutputDirectory>\n\n";
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
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                  return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);
my $sql			= '';
my $sth			= '';
my @row         = ();

#  Setting variables
my $sleepInterval = 10;     # 60 seconds

#  Load pmids to delete
my %PMIDsHash   = ();
if ((defined $ARGV[0]) && (-f $ARGV[0]))
{   open (FILE, $ARGV[0]);
    while(<FILE>)
    {   my $line        = $_;
        $line           =~ s/\r|\n//g;
        my @tmpSplit    = split (/\t/, $line);
        if ((defined $tmpSplit[0]) && ($tmpSplit[0] ne ""))
        {   $PMIDsHash{$tmpSplit[0]}    = 1;
        }
    }
    close FILE;
}else
{   die "! There is no PMID file to process\n\n".
		"! Usage\n".
		">ThisScript.pl [PMID File] <OutputDirectory>\n\n";
}

my @PMIDs = keys %PMIDsHash;


#  Check for output directory name
if (not defined $ARGV[1])
{   die "! There is no output directory specified\n";
}

mkdir ($ARGV[1]) || print "";

# ------------------------------------------------------------------------------
my $pmidCount	= scalar @PMIDs;
open (DOCUMENT, ">$ARGV[1]/DOCUMENT");
open (DOCMESH, ">$ARGV[1]/DOCMESH");
open (SENTENCE, ">$ARGV[1]/SENTENCE");
open (SENTOGENE, ">$ARGV[1]/SENTOGENE");
close DOCUMENT;
close DOCMESH;
close SENTENCE;
close SENTOGENE;

my @tmpArray	= ();
my $pmidString	= '';
my $roundCount	= 1;
my $newStr		= '';

for (my $i=0; $i < $pmidCount; $i+= 100)
{	print "Processing $roundCount(th) hundred(100)...\n";
	$roundCount++;
	
	my $endIndex	= $pmidCount;
	my $startIndex	= $i;
	
	my $addedEnd	= $i + 100;
	if ($addedEnd < $pmidCount)
	{	$endIndex	= $addedEnd;
	}
	
	@tmpArray	= ();
	$pmidString	= '';	
	
	for (my $j=$startIndex; $j < $endIndex; $j++)
	{	push @tmpArray, $PMIDs[$j];
	}
	$pmidString		= join (",", @tmpArray);
	
	#  retrieve from database
	#  document
	open (DOCUMENT, ">>$ARGV[1]/DOCUMENT");
    $sql         = "SELECT * FROM document WHERE pmid in ($pmidString)";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
	while(@row = $sth->fetchrow_array)
	{   for (my $k=0; $k < scalar @row; $k++)
		{	if (not defined $row[$k])
			{	$row[$k]	= '';
			}
		}
		$newStr	= join ("\t", @row);
		print DOCUMENT $newStr."\n";
	}	
	close DOCUMENT;
	
	#  document
	open (DOCMESH, ">>$ARGV[1]/DOCMESH");
    $sql         = "SELECT * FROM docmesh WHERE pmid in ($pmidString)";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
	while(@row = $sth->fetchrow_array)
	{   for (my $k=0; $k < scalar @row; $k++)
		{	if (not defined $row[$k])
			{	$row[$k]	= '';
			}
		}
		$newStr	= join ("\t", @row);
		print DOCMESH $newStr."\n";
	}	
	close DOCMESH;	

	#  SENTENCE
	open (SENTENCE, ">>$ARGV[1]/SENTENCE");
    $sql         = "SELECT * FROM sentence WHERE pmid in ($pmidString)";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
	while(@row = $sth->fetchrow_array)
	{   for (my $k=0; $k < scalar @row; $k++)
		{	if (not defined $row[$k])
			{	$row[$k]	= '';
			}
		}
		$newStr	= join ("\t", @row);
		print SENTENCE $newStr."\n";
	}	
	close SENTENCE;	
	
	#  SENTOGENE
	open (SENTOGENE, ">>$ARGV[1]/SENTOGENE");
    $sql         = "SELECT * FROM sentence2gene WHERE pmid in ($pmidString)";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
	while(@row = $sth->fetchrow_array)
	{   for (my $k=0; $k < scalar @row; $k++)
		{	if (not defined $row[$k])
			{	$row[$k]	= '';
			}
		}
		$newStr	= join ("\t", @row);
		print SENTOGENE $newStr."\n";
	}	
	close SENTOGENE;	
}


exit;

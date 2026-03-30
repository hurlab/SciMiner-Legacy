#!/usr/bin/perl -w
#############################################################################
#
#                       Generate_New_FULLHUGODATA
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           sciminer @ umich . edu
#
#      
#   Desc: This script will re-generate full hugo data from
#		  the current sentence2gene result
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

#  Load pmids to download
print "! Retrieving PMID list from document table...\n";
my @PMIDs 		= ();
$sql         	= "SELECT pmid FROM document";
$sth         	= $dbh->prepare($sql);
$sth->execute();
while(@row = $sth->fetchrow_array)
{   push @PMIDs, $row[0];
}

#  Retrieve hugoID2symbol
print "! Retrieving HUGO symbol and ID from gene table...\n";
my %hugoID2symbol	= ();
my %hugoID2Name		= ();
$sql         	= "SELECT hgncID, approvedSymbol, approvedName FROM gene";
$sth         	= $dbh->prepare($sql);
$sth->execute();
while(@row = $sth->fetchrow_array)
{	$hugoID2symbol{$row[0]}	= $row[1];
	$hugoID2Name{$row[0]}	= $row[2];
}


#  Retrieve sentence2gene
my $pmidIDCount		= scalar @PMIDs;
my @tmpArray		= ();
my $pmidString		= '';
my %hugoIDpmidHash	= ();
my %pmid2hugoHash	= ();

for (my $i=0; $i < $pmidIDCount; $i+=200)
{	print "! Processing ".($i+1)."th PMIDs...\n";
	my $startIndex	= $i;
	my $endIndex	= $i + 200;
	if ($endIndex > $pmidIDCount)
	{	$endIndex	= $pmidIDCount;
	}
	@tmpArray		= ();
	
	for (my $j=$startIndex; $j < $endIndex; $j++)
	{	push @tmpArray, $PMIDs[$j];
	}
	$pmidString		= join (',', @tmpArray);
	
	#  Retrieve docID for PMIDs
	$sql         	= "SELECT pmid, hgncID, score, inExClude FROM sentence2gene WHERE pmid in ($pmidString)";
	$sth         	= $dbh->prepare($sql);
	$sth->execute();
	while(@row = $sth->fetchrow_array)
	{   if ($row[3] > 1)
		{	next;
		}elsif ($row[3] == 1)
		{	if (not defined $pmid2hugoHash{$row[0]})
			{	my %tmpHash	= ();
				$tmpHash{$row[1]}	= 1;
				$pmid2hugoHash{$row[0]}	= \%tmpHash;
			}else
			{	$pmid2hugoHash{$row[0]}->{$row[1]}	= 1;
			}
			
			if (not defined $hugoIDpmidHash{$row[1]})
			{	my %tmpHash	= ();
				$tmpHash{$row[0]}	= 1;
				$hugoIDpmidHash{$row[1]}	= \%tmpHash;
			}else
			{	$hugoIDpmidHash{$row[1]}->{$row[0]}	= 1;
			}
		}else
		{	if ($row[2] > 0)
			{	if (not defined $pmid2hugoHash{$row[0]})
				{	my %tmpHash	= ();
					$tmpHash{$row[1]}	= 1;
					$pmid2hugoHash{$row[0]}	= \%tmpHash;
				}else
				{	$pmid2hugoHash{$row[0]}->{$row[1]}	= 1;
				}
				
				if (not defined $hugoIDpmidHash{$row[1]})
				{	my %tmpHash	= ();
					$tmpHash{$row[0]}	= 1;
					$hugoIDpmidHash{$row[1]}	= \%tmpHash;
				}else
				{	$hugoIDpmidHash{$row[1]}->{$row[0]}	= 1;
				}
			}
		}
	}
	
	#  -------------------------------------------------------------------------
}

open (FULLHUGO, ">FullSciMinerDBCorpus");
open (FULLGENE, ">FullSciMinerDBCorpus2HUGO");
open (FULLCOUNT, ">FullSciMinerDBCorpusPMIDCnt");

my @HUGOIDs		= keys %hugoIDpmidHash;
for (my $i=0; $i < scalar @HUGOIDs; $i++)
{	@tmpArray	= keys %{$hugoIDpmidHash{$HUGOIDs[$i]}};
	print FULLHUGO $hugoID2symbol{$HUGOIDs[$i]}."\t".$HUGOIDs[$i]."\t".
				   $hugoID2Name{$HUGOIDs[$i]}."\t".(scalar @tmpArray)."\n";
}
close FULLHUGO;

my $tmpString	= '';
for (my $i=0; $i < scalar @PMIDs; $i++)
{	@tmpArray	= keys %{$pmid2hugoHash{$PMIDs[$i]}};
	$tmpString	= join (",", @tmpArray);
	print FULLGENE $PMIDs[$i]."\t".$tmpString."\n";
}
close FULLGENE;

print FULLCOUNT (scalar @PMIDs)."\n";
close FULLCOUNT;

exit;

#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerDB_Content_Insert
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           sciminer @ umich . edu
#
#      
#   Desc: This script will insert transferred database content
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

my %ignoreCheck	= ();
#  Load term to ignore completely
if (-f "$annoENV{SciMinerPath}/Work/Dictionary/IGNORE_default")
{	open (IGNORE, "$annoENV{SciMinerPath}/Work/Dictionary/IGNORE_default");
	while(<IGNORE>)
	{	my $line = lc($_);          
		$line =~ s/\r|\n//g;
		$ignoreCheck{$line}	= 1;
		if ($line =~ /\-/)
		{	$line =~ s/\-/ /g;
			$ignoreCheck{$line}	= 1;
		}
	}
	close IGNORE;
	$ignoreCheck{"chemokine"}	= 1;
	$ignoreCheck{"helicase"}	= 1;
	$ignoreCheck{"homeobox"}	= 1;
}

#  -----------------------------------------------------------------------------
#  Check and insert directory
if (! -d $ARGV[0])
{	#  Directory existence
	die "! >ThisScript.pl [Directory name]";		
}

#  Check for file existence
my @tmpSplit	= ();
my %pmid2docID	= ();
my @PMIDs		= ();
if (-f "$ARGV[0]/DOCUMENT")
{	print STDERR "! Inserting data into document table ...\n";
	open (FILE, "$ARGV[0]/DOCUMENT");
	while(<FILE>)
	{	my $line = $_;
		$line =~ s/\r|\n//g;
		@tmpSplit = split (/\t/, $line);
		
		#  Add pmid to the array
		push @PMIDs, $tmpSplit[1];
		
		#  Process possible double quatation mark in abstract
		$tmpSplit[12]	=~ s/\"/\\\"/g; 
		$tmpSplit[6]	=~ s/\"/\\\"/g; 
		
		#  Process journalType, linkURL, linkURLOriginal for NULL value
		if (not defined $tmpSplit[6])
		{	$tmpSplit[6]	= '';
		}
		if (not defined $tmpSplit[7])
		{	$tmpSplit[7]	= '';
		}
		if (not defined $tmpSplit[8])
		{	$tmpSplit[8]	= '';
		}
		if (not defined $tmpSplit[15])
		{	$tmpSplit[15]	= '';
		}

		#  Insert into database
		
		#print "INSERT INTO document (pmid, medline, medlineSize, html, htmlSize, title, journalType, linkURL, source, statusProcessed, statusMined, abstract, lang, journal, linkURLOriginal) VALUES ($tmpSplit[1], $tmpSplit[2], $tmpSplit[3], $tmpSplit[4], $tmpSplit[5], \"$tmpSplit[6]\",  \"$tmpSplit[7]\",  \"$tmpSplit[8]\", $tmpSplit[9], $tmpSplit[10], $tmpSplit[11], \"$tmpSplit[12]\",  \"$tmpSplit[13]\", \"$tmpSplit[14]\", \"$tmpSplit[15]\")\n";
		
		$dbh->do("INSERT INTO document (pmid, medline, medlineSize, html, htmlSize, title, journalType, linkURL, source, statusProcessed, statusMined, abstract, lang, journal, linkURLOriginal) VALUES ($tmpSplit[1], $tmpSplit[2], $tmpSplit[3], $tmpSplit[4], $tmpSplit[5], \"$tmpSplit[6]\",  \"$tmpSplit[7]\",  \"$tmpSplit[8]\", $tmpSplit[9], $tmpSplit[10], $tmpSplit[11], \"$tmpSplit[12]\",  \"$tmpSplit[13]\", \"$tmpSplit[14]\", \"$tmpSplit[15]\")") || print STDERR "!ERROR in $tmpSplit[1] insertion\n"; #print STDERR "!ERROR: PMID $tmpSplit[1] insertion\n";
	}
	close FILE;

	
	#  -------------------------------------------------------------------------
	#  Retrieve docID and pmid
	my $pmidTotalCount	= scalar @PMIDs;
	my $pmidString		= '';
	my @tmpArray		= ();
	for (my $i=0; $i < $pmidTotalCount; $i+=100)
	{	my $startIndex	= $i;
		my $endIndex	= $i + 100;
		if ($endIndex > $pmidTotalCount)
		{	$endIndex	= $pmidTotalCount;
		}
		@tmpArray		= ();
		
		for (my $j=$startIndex; $j < $endIndex; $j++)
		{	push @tmpArray, $PMIDs[$j];
		}
		$pmidString		= join (',', @tmpArray);
		
		#  Retrieve docID for PMIDs
		$sql         	= "SELECT pmid, docID FROM document WHERE pmid in ($pmidString)";
		$sth         	= $dbh->prepare($sql);
		$sth->execute();
		while(@row = $sth->fetchrow_array)
		{   $pmid2docID{$row[0]}	= $row[1];
		}
	}
	
	
	# --------------------------------------------------------------------------
	#	DOCMESH
	if (-f "$ARGV[0]/DOCMESH")
	{	print STDERR "! Inserting data into docmesh table ...\n";
		open (DOCMESH, "$ARGV[0]/DOCMESH");
		while(<DOCMESH>)
		{	my $line = $_;
			$line =~ s/\r|\n//g;
			@tmpSplit = split (/\t/, $line);
			
			#  Check $tmpSplit[5]
			if (not defined $tmpSplit[5])
			{	$tmpSplit[5]	= "";
			}
			
			#  Check $tmpSplit[6]
			if (not defined $tmpSplit[6])
			{	$tmpSplit[6]	= "";
			}
			
			#  Insert into database
			$dbh->do("INSERT INTO docmesh (docID, pmid, explicit, descIDString, treeCode, descTermNoTree) VALUES ($pmid2docID{$tmpSplit[2]}, $tmpSplit[2], \"$tmpSplit[3]\", \"$tmpSplit[4]\", \"$tmpSplit[5]\", \"$tmpSplit[6]\")") || print STDERR "!ERROR: DOCMESH $tmpSplit[2] insertion\n";
		}
		close DOCMESH;
	}
	
	# --------------------------------------------------------------------------
	#	SENTENCE
	my %oldsenID2newsenID	= ();
	if (-f "$ARGV[0]/SENTENCE")
	{	open (SENTENCE, "$ARGV[0]/SENTENCE");
		print STDERR "! Inserting data into sentence table ...\n";
		while(<SENTENCE>)
		{	my $line = $_;
			$line =~ s/\r|\n//g;
			if ($line eq "")
			{	next;
			}
			
			@tmpSplit = split (/\t/, $line);
		
			#  Check $tmpSplit[6]
			if (not defined $tmpSplit[6])
			{	$tmpSplit[6]	= "";
			}
			
			#  Process double quotation mark
			$tmpSplit[6] =~ s/\"/\\\"/g;
			
			#  Insert into database
			$dbh->do("INSERT INTO sentence (docID, pmid, secAnchor, paraNum, pNum, sentence) VALUES ($pmid2docID{$tmpSplit[2]}, $tmpSplit[2], \"$tmpSplit[3]\", $tmpSplit[4], $tmpSplit[5], \"$tmpSplit[6]\")") || print STDERR "!ERROR: SENTENCE $tmpSplit[2] insertion\n";
			
			#  Retrieve new senID and assign
            $sth                    = $dbh->prepare("SELECT senID FROM sentence ORDER BY senID DESC LIMIT 1");
            $sth->execute();
            @row                    = $sth->fetchrow_array;#($result);
            $oldsenID2newsenID{$tmpSplit[0]}	= $row[0];
		}
		close SENTENCE;
	}	
	
	# --------------------------------------------------------------------------
	#	SENTOGENE
	if (-f "$ARGV[0]/SENTOGENE")
	{	open (SENTOGENE, "$ARGV[0]/SENTOGENE");
		print STDERR "! Inserting data into sentence2gene table ...\n";
		while(<SENTOGENE>)
		{	my $line = $_;
			$line =~ s/\r|\n//g;
			@tmpSplit = split (/\t/, $line);
		
			if (defined $ignoreCheck{$tmpSplit[7]})
			{	next;
			}
			
			#  Process double quotation mark in flanking text
			$tmpSplit[10] =~ s/\"/\\\"/g;
			
			#  Check $tmpSplit[20]
			if (not defined $tmpSplit[20])
			{	$tmpSplit[20]	= "";
			}
			
			#  Check $tmpSplit[25]
			if (not defined $tmpSplit[25])
			{	$tmpSplit[25]	= "";
			}
			
			#  Check $tmpSplit[27]
			if (not defined $tmpSplit[27])
			{	$tmpSplit[27]	= "";
			}
			
			
			#  Insert into database
			$dbh->do("INSERT INTO sentence2gene (pmid, senID, geneID, hgncID, approvedSymbol, matchString, actualString, startPos, score, flankingText, matchCodeID, tag, SciMinerVersion, SciMinerMethod, inExClude, inExCludeCond, phenotypeOnly, conflictCode, hgncIDbyNR, NRText, editTag, editUser, oldGeneID, oldHgncID, oldApprovedSymbol, oldInExClude, oldInExCludeCond ) VALUES ($tmpSplit[1], $oldsenID2newsenID{$tmpSplit[2]}, $tmpSplit[3], $tmpSplit[4], \"$tmpSplit[5]\", \"$tmpSplit[6]\", \"$tmpSplit[7]\", $tmpSplit[8], $tmpSplit[9], \"$tmpSplit[10]\", $tmpSplit[11], \"$tmpSplit[12]\", \"$tmpSplit[13]\", $tmpSplit[14], $tmpSplit[15], \"$tmpSplit[16]\", $tmpSplit[17], $tmpSplit[18], $tmpSplit[19], \"$tmpSplit[20]\", $tmpSplit[21], $tmpSplit[22], $tmpSplit[23], $tmpSplit[24], \"$tmpSplit[25]\", $tmpSplit[26], \"$tmpSplit[27]\")");
			
		}
		close SENTOGENE;
	}		
	
}

print "Process completed\n";

exit;

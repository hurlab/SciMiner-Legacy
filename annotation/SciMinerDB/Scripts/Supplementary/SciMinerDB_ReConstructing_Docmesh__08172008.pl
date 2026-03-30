#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerDB_ReConstructing_DocMeSH__08172008
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           sciminer @ umich . edu
#
#      
#   Desc: This script will reconstruct a truncated docmesh table
#		  for a new format (08/17/2008) with descIDString column
#
#	Steps: 	1) Retrieve all pmid in the document table
#			2) Load MeSH description data from SciMinerDB
#			3) Process medline documents to get MeSH data and insert into SciMinerDB
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
my @PMIDs		= ();
my $PMIDCount	= 0;
my %pmid2docID	= ();


#  -----------------------------------------------------------------------------
#  Step 1 : Retrieving all pmids from 'document' table
#  -----------------------------------------------------------------------------
print "! Retrieving document table info...\n";
$sql		= "SELECT docID, pmid FROM document WHERE medlineSize <> 0";
$sth		= $dbh->prepare($sql);
$sth->execute();
while(@row 	= $sth->fetchrow_array)
{   if (defined $row[1])
	{	push @PMIDs, $row[1];
		$pmid2docID{$row[1]}	= $row[0];
	}
}	
$PMIDCount	= scalar @PMIDs;


#  -----------------------------------------------------------------------------
#  Step 2 : Load MeSH description data from SciMinerDB
#  -----------------------------------------------------------------------------
print "! Retrieving MeSH description info...\n";
my ($MeSHdescID2termRef, $MeSHTerm2descIDRef)	= load_mesh_tree_data_from_SciMinerDB_simplified ($dbh, 0);



#  -----------------------------------------------------------------------------
#  Step 3 : Process medline documents to get MeSH data and insert into SciMinerDB
#  -----------------------------------------------------------------------------
my $medlineFile				= '';
my $pmid					= '';
my $baseDir					= "$annoENV{SciMinerPath}CorpusData/Original/";
my @tmpSplit				= ();
my @MeSHTermInDoc			= ();	
my $line					= '';
my $tmpDescIDString			= '';

print "! Processing individual medline document file...\n";
for (my $i=0; $i < $PMIDCount; $i++)
{	$medlineFile			= $baseDir.$PMIDs[$i].'.medline';
	$pmid					= $PMIDs[$i];
	if (($i % 100) == 0)
	{	print "! -- processing $i th document..\n";
	}
	
	if (-f $medlineFile)
	{	open (FILE, $medlineFile);
		@MeSHTermInDoc	= ();
		while(<FILE>)
		{   $line = $_;
		    $line =~ s/\r|\n//g;
		    
		    if ($line =~ /^MH  - \*?(\S.*)/ )
		    {   @tmpSplit = split (/\//, $1);   
				push @MeSHTermInDoc, $tmpSplit[0];
		    }
		}
		close FILE;
		
		#  Explore MeSH tree to extract implicit MeSH Terms
		$tmpDescIDString	= '';
		if (defined $MeSHTermInDoc[0])
		{   foreach my $localMeSHTerm (@MeSHTermInDoc)
			{   if (defined $$MeSHTerm2descIDRef{$localMeSHTerm})
				{	$tmpDescIDString .= $$MeSHTerm2descIDRef{$localMeSHTerm}.';';
				}
			}

			if( $tmpDescIDString ne "")
			{	$dbh->do("INSERT INTO `docmesh` (docID, pmid, explicit, descIDString) VALUES ($pmid2docID{$pmid}, $pmid, \"E\", \"$tmpDescIDString\")") || print "!ERROR: docmesh insertion $pmid";
			}
		}
	}else
	{	print "! MEDLINE File $pmid.medline does not exist in the reservor directory...\n";
	}
}

print "! Process completed...\n\n";


exit;

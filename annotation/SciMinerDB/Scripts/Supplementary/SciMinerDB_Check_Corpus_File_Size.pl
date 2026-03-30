#!/usr/bin/perl -w
#
# This script checks the size of the medline and html files
# for any zero sized file.
#

use strict;
use warnings;

print "! Loading file names...\n";
my @medlineFileNames 	= glob("/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/CorpusData/Original/*.medline");
my @htmlFileNames		= glob("/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/CorpusData/Original/*.html");
print "! Loading completed...\n";

my @medlineZeroFilePMID	= ();
my @htmlZeroFilePMID	= ();

my $medlineFileCount	= scalar @medlineFileNames;
my $htmlFileCount		= scalar @htmlFileNames;

print "! Checking Medline file size...\n";
for (my $i=0; $i < $medlineFileCount; $i++)
{	my $fileSize	= -s $medlineFileNames[$i];
	if ($fileSize == 0)
	{	my @tmp1	= split (/\//, $medlineFileNames[$i]);
		my @tmp2	= split (/\./, $tmp1[$#tmp1]);
		push @medlineZeroFilePMID, $tmp2[0];
	}
}

if (defined $medlineZeroFilePMID[0])
{	open (MEDLINEZERO, ">Zero-Sized_Medline_PMIDs.txt");
	foreach my $pmid (@medlineZeroFilePMID)
	{	print MEDLINEZERO $pmid."\n";
	}
	close MEDLINEZERO;
}

print "! Checking Html file size...\n";
for (my $i=0; $i < $htmlFileCount; $i++)
{   my $fileSize    = -s $htmlFileNames[$i];
    if ($fileSize == 0)
    {   my @tmp1    = split (/\//, $htmlFileNames[$i]);
        my @tmp2    = split (/\./, $tmp1[$#tmp1]);
        push @htmlZeroFilePMID, $tmp2[0];
    }   
}
								 
if (defined $htmlZeroFilePMID[0])
{   open (HTMLZERO, ">Zero-Sized_Html_PMIDs.txt");
    foreach my $pmid (@htmlZeroFilePMID)
    {   print HTMLZERO $pmid."\n";
    }   
    close HTMLZERO;
}

print "\n! Process completed\n".
	  "Total medline file	: ".($medlineFileCount)."\n".
	  "Zero-sized medline	: ".(scalar @medlineZeroFilePMID)."\n".
	  "Total html file		: ".($htmlFileCount)."\n".
	  "Zero-sized html		: ".(scalar @htmlZeroFilePMID)."\n";



#!/usr/bin/perl -w
# ----------------------------------------------------------------------------
#  Specify the Annotation modules location
# ----------------------------------------------------------------------------
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}
use warnings;
use strict;
use Annotation::basicIO;            
use Annotation::SciMiner;   

# ------------------------------------------------------------------------------
#	This script will 
#		1) read a list of PMID
#		2) DELETE any matching document from the repository directory. 
#
# ------------------------------------------------------------------------------

#  Load working environment for ANNOTATION
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};

#  Check commandline options
if (not defined $ARGV[0])
{	die "! Not enough command line options has been specified.\n".
		">perl ThisScript.pl <PMID_FILE>\n\n";
}

#  Open the PMID file
if (! -f $ARGV[0])
{	die "! The specified PMID list file does NOT exist...\n\n";
}
open (PMID, $ARGV[0]) || die "! Can't open the PMID list file...\n\n";
my @PMIDs	= ();
while(<PMID>)
{   my $line = $_;
	$line =~ s/\r|\n//g;
	push @PMIDs, $line;
}	
close PMID;

#  Copy document files to the specified local directory
my $repository	= "$annoENV{SciMinerPath}/CorpusData/Original/";

#  Additional confirmation
print 	"\nThis script will delete any existing documents (.html, .medline, .enw) from the repository.\n".
		"Do you want to proceed (y/N)? ";
chomp(my $userChoice = <STDIN>);

if (uc($userChoice) eq 'Y')
{	for (my $i=0; $i <= $#PMIDs; $i++)
	{	#  Process MEDLINE
		my $medlineFile	= $repository.$PMIDs[$i].'.medline';
		my $htmlFile	= $repository.$PMIDs[$i].'.html';
		my $enwFile		= $repository.$PMIDs[$i].'.enw';	
		
		if (-f $medlineFile )
		{	`rm -Rf $medlineFile`;
		}
		if (-f $htmlFile )
		{	`rm -Rf $htmlFile`;
		}
		if (-f $enwFile )
		{	`rm -Rf $enwFile`;
		}
	}

	print "\n! Process completed...\n\n";
}else
{	print "\n! Process canceled by user...\n\n";
}





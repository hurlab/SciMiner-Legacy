#!/usr/bin/perl -w
# ----------------------------------------------------------------------------
#  Specify the Annotation modules location
# ----------------------------------------------------------------------------
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;            
use strict;
use warnings;


#  Load working environment for ANNOTATION
my %annoENV = anno_environmental_file_open ( );
my $SciMinerBasePath 	= $annoENV{SciMinerPath};
my $CorpusOriginalDir	= $SciMinerBasePath.'CorpusData/Original/';


#  Read the list of medline in the corpus original folder
my @medlineFiles 		= glob($CorpusOriginalDir."*.medline");
my $medlineFileCount	= scalar @medlineFiles;

my @enwFiles			= glob($CorpusOriginalDir."*.enw");
my $enwFileCount		= scalar @enwFiles;

my $diffCount			= $medlineFileCount - $enwFileCount;

print "SciMiner has found ------ \n".
	  "\tmedline files : $medlineFileCount\n".
	  "\tendnote files : $enwFileCount\n\n".
	  "$diffCount more medline files will be converted to endnote format\n\n";

if ($diffCount <= 0)
{	exit;
}


my $success	= 0;
my $error	= 0;

for (my $i=0; $i < $medlineFileCount; $i++)
{   my $pmid 	= '';
	if ($medlineFiles[$i] =~ /\/(\d+)\.medline/)
	{	$pmid	= $1;
	}else
	{	next;
	}
	
	if (! -f $CorpusOriginalDir.$pmid.'.enw')
	{	print "Processing PMID $pmid ...";
		my $status = convert_medline_2_endnote ($medlineFiles[$i], $CorpusOriginalDir.$pmid.'.enw');
		if ($status == 1)
		{   print "success\n";
			$success++;
		}else
		{   print "error\n";
			$error++;
		}
	}else
	{   # Nothing to be done.
	}
}

print "\n-------------------------------------------------------------\n";
print "Success : $success\n";
print "Error   : $error\n\n";

exit;




# ----------------------------------------------------------------------------
#  Endnote Related Subroutine collection
# ----------------------------------------------------------------------------
sub convert_medline_2_endnote
{	my $medlineFile	= shift;
	my $endnoteFile	= shift;
	
	if (not defined $medlineFile)
	{	return(-1);
	}

	# Load MedLine file
	my @origContent		= ();
	my @headerArray		= ();
	my @contentArray	= ();

	open (MEDLINE, $medlineFile) || return(-1);
	while(<MEDLINE>)
	{   my $line = $_;
		$line =~ s/\r|\n//g;
		if ($line !~ /\S/)
		{   next;
		}
		push @origContent, $line;
	}
	close MEDLINE;

	# Process the Medline contents
	Process_MedLine_File_By_Header_text(\@origContent, \@headerArray, \@contentArray);

	# Generate EndNote file format content
	my $convertedTextRef	= PubMed2EndNote(\@headerArray, \@contentArray);

	# Create output file
	if (defined $convertedTextRef)
	{	open (OUTFILE, ">".$endnoteFile) || return(-2);
		print OUTFILE $$convertedTextRef;
		close OUTFILE;
	}else
	{   return(-2);
	}

	return(1);
}





sub Process_MedLine_File_By_Header_text
{	my $origContentRef	= shift;
	my $headerArrayRef	= shift;
	my $contentArrayRef	= shift;
	
	for (my $i=0; $i < scalar @{$origContentRef}; $i++)
	{   if (substr($$origContentRef[$i], 4, 1) eq '-')
		{	# Process the header
			my $tmpHeader 	= substr($$origContentRef[$i], 0, 4);
			$tmpHeader 		=~ s/ //g;
			push @{$headerArrayRef}, $tmpHeader;
			
			# Process the remaining test
			push @{$contentArrayRef}, substr($$origContentRef[$i], 6);
		}else
		{	# Add the text to the end of the array (contentArray)
			if (length($$origContentRef[$i]) > 5)
			{   $$contentArrayRef[$#$contentArrayRef] .= substr($$origContentRef[$i], 5);
			}else
			{   # Do nothing
			}
		}
	}
}

# Convert MedLine format to EndNote.enw file format
sub PubMed2EndNote
{	my $MedLineHeadersArrayRef	= shift;
	my $MedLineContentArrayRef	= shift;
	
	my $outputText	= "\n\n\n\n".
					  "%0 Journal Article\n";
	
	# The following mapping is based on P213. Chapter 7. Importing Reference Data into EndNote
	# of the EndNoteX1 Manual and a few actual examples of PubMed Medline format documents
	# and imported records.
	my %MedLineHeader2EndNoteHeader	= (
		'AB'	=>	'%X',
		'AD'	=>	'%+',
		'AID'	=>	'%R',
		'AU'	=>	'%A',
		'CN'	=>	'%Z',
		'FAU'	=>	'%Z',
		'GR'	=>	'%Z',
		'JT'	=>	'%Z',
		'MID'	=>	'%Z',
		'PL'	=>	'%Z',
		'PT'	=>	'%Z',
		'SO'	=>	'%Z',	
		'IP'	=>	'%N',	
		'IS'	=>	'%@',	
		'LA'	=>	'%G',	
		'MH'	=>	'%K',	
		'OWN'	=>	'%W',	
		'PG'	=>	'%P',	
		'PMID'	=>	'%M',	
		'TA'	=>	'%J',	
		'TI'	=>	'%T',
		'TT'	=>	'%(',	
		'VI'	=>	'%V',	
		'URL'	=>	'%U',	
		'URLF'	=>	'%U',	
		'URLS'	=>	'%U',	
		'4099'	=>	'%U',	
		'4100'	=>	'%U',	
		'PMC'	=>	'%2',
		'PG'	=>	'%P'
		);
	
	my $pmid	= '';
	
	# Process the MedLine text
	for (my $i=0; $i < scalar @{$MedLineHeadersArrayRef}; $i++)
	{	if (defined $MedLineHeader2EndNoteHeader{$$MedLineHeadersArrayRef[$i]})
		{	if ($$MedLineHeadersArrayRef[$i] eq 'AU')
			{	my $tmpString	= $$MedLineContentArrayRef[$i];
				$tmpString		=~ /^(\S+)/;
				
				# Check the end character
				if (substr($tmpString,-1,1) ne ',')
				{	$tmpString	= $1.','.$';
					$$MedLineContentArrayRef[$i]	= $tmpString;
				}
			}
			
			$outputText .= $MedLineHeader2EndNoteHeader{$$MedLineHeadersArrayRef[$i]}.' '.$$MedLineContentArrayRef[$i]."\n";
			if ($$MedLineHeadersArrayRef[$i] eq 'PMID')
			{	$pmid	= $$MedLineContentArrayRef[$i];
			}
		}else
		{   if ($$MedLineHeadersArrayRef[$i] eq 'DP')
			{	if ($$MedLineContentArrayRef[$i] =~ /^(\d+)/)
				{	my $year	= $1;
					$outputText .= '%D '.$year."\n";
					$outputText .= '%8 '.$$MedLineContentArrayRef[$i]."\n";
				}
			}
			# elsif ($$MedLineHeadersArrayRef[$i] eq 'PMC')
			# {	if ($$MedLineContentArrayRef[$i] =~ /^PMC(\d+)/)
				# {	$outputText .= '%2 '.$1."\n";
				# }elsif ($$MedLineContentArrayRef[$i] =~ /^(\d+)/)
				# {	$outputText .= '%2 '.$1."\n";
				# }
			# }
		}
	}
	
	# Add the PubMed link URL
	if ((defined $pmid) && ($pmid ne ""))
	{   $outputText .= '%U http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=Citation&list_uids='.$pmid."\n";
	}
	
	$outputText	.= "\n\n\n";
	
	# return the reference address of the output variable
	return(\$outputText);
}

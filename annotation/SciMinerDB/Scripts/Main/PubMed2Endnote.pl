#!/usr/bin/perl -w

use strict;
use warnings;

# Check input and output file parameters
if ((not defined $ARGV[1]) || (! -f $ARGV[0]))
{	die "!ERROR! Missing parameters...\n\n".
		"Usage: >PubMed2EndNote.pl <INFILE> <OUTFILE>\n".
		"ex)    >PubMed2EndNote.pl 18467592.medline 18467592.enw\n\n";
}

# Load MedLine file
my @origContent		= ();
my @headerArray		= ();
my @contentArray	= ();

open (MEDLINE, $ARGV[0]) || die "!ERROR: Can't open $ARGV[0] \n\n";
while(<MEDLINE>)
{   my $line = $_;
	$line =~ s/\r|\n//g;
	push @origContent, $line;
}
close MEDLINE;

# Process the Medline contents
Process_MedLine_File_By_Header_text(\@origContent, \@headerArray, \@contentArray);

# Get the pmid

# Generate EndNote file format content
my $convertedTextRef	= PubMed2EndNote(\@headerArray, \@contentArray);

# Create output file
if (defined $convertedTextRef)
{	open (OUTFILE, ">".$ARGV[1]) || die "!ERROR: Can't create the result file $ARGV[1]\n\n";
	print OUTFILE $$convertedTextRef;
	close OUTFILE;
	print "!Success\n";
}else
{   print "!ERROR: Conversion failed...\n";
}
exit;






# ----------------------------------------------------------------------------
# Subroutine collection
# ----------------------------------------------------------------------------
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
			$$contentArrayRef[$#$contentArrayRef] .= substr($$origContentRef[$i], 5);
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

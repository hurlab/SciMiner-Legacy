#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                retrieveDocument.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Created       : Aug 08, 2008
#  Desc:  This cgi accepts parameters from SciMiner and retrieve
#			the locally saved MEDLINE, HTML, or EndNote files
#
#******************************************************************************
BEGIN {
push (@INC, "/home/sciminer/legacy/annotation/SciMinerDB/Modules/");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;            
use Annotation::SciMiner;            
use CGI qw(:standard);
use CGI::Debug;
#use warnings;                       
use strict;

#here's a stylesheet incorporated directly into the page
my  $newStyle=<<END;
<!-- 
body {
    margin-left: 10px;
}
-->
END

# here is some javascript
my $JSCRIPT=<<EOF;
function closeW()
{	var finalResultURLString	= document.getElementsByName("finalResultURL")[0].value;
	var finalStatusString		= document.getElementsByName("finalStatus")[0].value;
	var messageStatusString		= document.getElementsByName("messageStatus")[0].value;

	if (messageStatusString == "no")
	{	if (finalStatusString == "local")
		{	var hostURL				= window.location.host;
			var fullURLListFile		= 'http://' + hostURL + '/SciMiner/' + finalResultURLString;
			alert(fullURLListFile);
			window.open(finalResultURLString);
			window.opener = self;
			window.close();
		}elsif (finalStatusString == "remote")
		{	window.open(finalResultURLString);
			window.opener = self;
			window.close();
		}
	}
}  
EOF

# ----------------------------------------------------------------------------
#  Load working environment for ANNOTATION
# ----------------------------------------------------------------------------
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};
my $annoBaseRawData = $annoENV{ANNOPath}.'DB_RawData/';
my $annoBaseWorkingI = $annoENV{ANNOPath}.'DB_Working_I/';
my $annoBaseWorkingII = $annoENV{ANNOPath}.'DB_Working_II/';


#------------------------------------------------------------------------------
#  Automatically update the server's current URL for cgi-bin
#------------------------------------------------------------------------------
my $query = new CGI;
my $my_url = $query->self_url;
my @tmpSplit1 = split(/\/\//, $my_url);
my @tmpSplit2 = split(/\//, $tmpSplit1[1]);
my $tmpLocalURL = "http://$tmpSplit2[0]/";




#------------------------------------------------------------------------------
#  Initialize varialbes
#------------------------------------------------------------------------------
my $CurrentDate = `date`;
#my $currentNewDate = getdate();


#------------------------------------------------------------------------------
#  Initialize the CGI page
#------------------------------------------------------------------------------
print header;
print $query->start_html(-title=>'SciMiner Document Retireval', 
                        -author=>'InformaticsTools@gmail.com',
                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
                        -BGCOLOR=>'#EAF4F4',
                        -script=> $JSCRIPT,
                        -style=>{-src=>['mm_health_nutr.css'], -code=>$newStyle},
                        -onLoad=>'closeW()'
                        
                        );

#print $query->start_html(-title=>'SciMiner CGI', 
#                        -author=>'windysky.open@gmail.com',
#                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
#                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
#                        -script=>{-language	=>	'javascript1.2',
#                        		  -src     	=>	'./sciminer.js'}
#                        -BGCOLOR=>'#EAF4F4');
                        
print_SciMiner_Header();


#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------
my $endnoteAll			= param("endnoteAll");
my $pmidSelect			= param("pmidSelect");
my $fileExtension		= param("fileExtension");
my $resultBaseDir		= param("resultBaseDir");
my $htmlURL				= param("htmlURL");

if ((defined $htmlURL) && ($htmlURL ne ""))
{	$htmlURL			=~ s/-_-/\&/g;
}
my @errorMessage    	= ();
my @targetPMIDs     	= ();
my $queueSuccess    	= 0;
my $passCheckResult 	= 1;

my %hugoID2Symbol		= ();
my %hugoSymbol2ID		= ();
my %hugoID2Name			= ();
my @hugoIDs				= ();
my $hugoIDCnt			= 0;
my $hugoIDCntTotal		= 0;
my %hugoID2Occur		= ();
my %hugoID2Paper		= ();
my $MinTopCheck			= 'true';

my $outputBaseDir		= "../$resultBaseDir/";
my $outputDocsDir		= $outputBaseDir."Docs/";
mkdir ($outputDocsDir) || print "";

#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
my $finalResultURL	= '';
my $finalStatus		= 'local';

if ( ((defined $endnoteAll) && ($endnoteAll ne "")) &&
	 ((defined $pmidSelect) && ($pmidSelect ne "")) &&
	 ((defined $resultBaseDir) && ($resultBaseDir ne "")) &&
	 ((defined $fileExtension) && ($fileExtension ne ""))
   )
{	#  Check for file existence
	if ($fileExtension	eq 'medline')
	{	# Generate URL to NCBI efetch utilities
		$finalResultURL	= 'http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&rettype=medline&id='.$pmidSelect;
		$finalStatus	= 'remote';
	}elsif ($fileExtension	eq 'html')
	{	#  check for result file
		$finalResultURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&retmode=ref&cmd=prlinks&id=".$pmidSelect;
		$finalStatus	= 'remote';
	}elsif ($fileExtension	eq 'enw')
	{	$finalResultURL	= $outputDocsDir."$pmidSelect.enw";
	}
}else
{	push @errorMessage, "Required parameters are missing";
	push @errorMessage, "endnoteAll: $endnoteAll";
	push @errorMessage, "pmidSelect: $pmidSelect";
	push @errorMessage, "resultBaseDir: $resultBaseDir";
	push @errorMessage, "fileExtension: $fileExtension";
}
	 
	 
#------------------------------------------------------------------------------
#	Check error message and display
#------------------------------------------------------------------------------
if (defined $errorMessage[0])
{	display_errorMessage_SciMiner_CGI(\@errorMessage);
	print "<input type=\"hidden\" name=\"messageStatus\" value=\"yes\">\n";	
	print_end_html();
}else
{	# Create the URL
	print "<input type=\"hidden\" name=\"finalResultURL\" value=\"$finalResultURL\">\n";
	print "<input type=\"hidden\" name=\"finalStatus\" value=\"$finalStatus\">\n";	
	print "<input type=\"hidden\" name=\"messageStatus\" value=\"no\">\n";	
	print_end_html();
}








exit;




sub print_SciMiner_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>Document Retrieval</U></b></p>
           ";
}


sub print_end_html
{   print end_html;
}

sub display_errorMessage_SciMiner_CGI
{   my $errorMessageRef = shift;
    
    if (not defined $errorMessageRef)
    {   return;
    }
    
    print "<font color=\"red\">";
    for (my $i=0; $i < scalar @{$errorMessageRef}; $i++)
    {   if ($$errorMessageRef[$i] ne "")
        {   print " Error ".($i+1).": $$errorMessageRef[$i]<br>";
        }
    }
    print "</font>";
}










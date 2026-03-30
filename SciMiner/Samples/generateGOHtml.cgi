#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                generateGOHtml.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Created       : Aug 05, 2008
#  Desc:  This cgi accepts parameters from SciMiner and generate a file 
#         with selected pathway
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
print $query->start_html(-title=>'Selected Target Lists - SciMiner', 
                        -author=>'InformaticsTools@gmail.com',
                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
                        -BGCOLOR=>'#EAF4F4',
                        -script=>{-language=>'javascript1.2', -src=>'sciminer.js'},
                        -style=>{-src=>['mm_health_nutr.css'], -code=>$newStyle}
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
my $goID					= param("goID");
my $dirBaseName				= param("dirBaseName");
my $fileBaseName			= param("fileBaseName");
								  
my @errorMessage    		= ();
my @targetPMIDs     		= ();
my $queueSuccess    		= 0;
my $passCheckResult 		= 1;

my $goTxtFile				= $dirBaseName.$fileBaseName;
my $newHTMLToBeCreated		= $goTxtFile;
substr($newHTMLToBeCreated, -3)		= 'html';

my $hgncLinkURL         	= "https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/";
my $ncbiGeneLink			= "https://www.ncbi.nlm.nih.gov/gene/";
my $ebiGOLink				= "https://www.ebi.ac.uk/QuickGO/term/";

#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
if ( ((defined $goID) && ($goID ne "")) &&
	 ((defined $dirBaseName) && ($dirBaseName ne "")) &&
	 ((defined $fileBaseName) && ($fileBaseName ne "")) 
   )
{		
	print "<p class='titleBarName1'><a href=\"$ebiGOLink$goID\"><b>$goID</b></a> ($dirBaseName$fileBaseName) <a href=\"$goTxtFile\">Download Text</a></p>";
	
	if (-f $newHTMLToBeCreated)
	{	#  Simply display the content
		open (HTMLFILE, $newHTMLToBeCreated);
		while(<HTMLFILE>)
		{	my $line = $_;
			print $line;
		}	close HTMLFILE;
	}else
	{	#  Load original txt file
		open (ORIGINAL, $goTxtFile);
		
		my $headerString	= '';
		my $mainContent		= 	"<table border=\"1\" width=\"880\">
                                	<tr class=\"titleBarName1\">
		                                <th width=\"130\">
		                                	Class
		                                </th>
		                                <th width=\"100\">
		                                	HUGOID
		                                </th>
		                                <th width=\"100\">
		                                	Symbol
		                                </th>
		                                <th width=\"150\">
		                                	NCBI_Gene
		                                </th>
		                                <th width=\"400\">
		                                	Name
		                                </th>
                               		</tr>
                                    ";
		
		while(<ORIGINAL>)
		{	my $line	= $_;
			$line		=~ s/\r|\n//g;
			if ($line =~ /^#/)
			{	$headerString 	.= $line."<br>";
			}else
			{	if ($line ne "")
				{	my @tmp		= split (/\t/, $line);
					$mainContent		.= 	"<tr>
											";
					if ($tmp[0] eq 'TESTONLY')
					{	$mainContent	.= 	"<td bgcolor=\"#FA6161\">
											";
					}elsif ($tmp[0] eq 'COMMON')
					{	$mainContent	.= 	"<td bgcolor=\"#F3F798\">
											";
					}else 
					{	$mainContent	.= 	"<td bgcolor=\"#75FA95\">
											";
					}
					
					$mainContent		.=  "
													$tmp[0]
												</td>
												<td>
													<a href=\"$hgncLinkURL$tmp[1]\">$tmp[1]</a>
												</td>
												<td>
													$tmp[2]
												</td>
												<td>
													<a href=\"$ncbiGeneLink$tmp[3]\">$tmp[3]</a>
												</td>
												<td>
													$tmp[4]
												</td>
											</tr>
											";
				}
			}
		}	close ORIGINAL;
		
		
		$mainContent	.= "</table><p>&nbsp;</p>\n";
		
		open (NEWHTML, ">".$newHTMLToBeCreated);
		print NEWHTML	$headerString."\n";
		print NEWHTML 	$mainContent;
		print $headerString."\n";
		print $mainContent;
		close NEWHTML;
	}
}else
{	push @errorMessage, "Some required parameters are not specified...";
	push @errorMessage, "goID $goID<br>";
	push @errorMessage, "dirBaseName $dirBaseName<br>";
	push @errorMessage, "fileBaseName $fileBaseName<br>";
}
	 
	 
	 
#------------------------------------------------------------------------------
#	Check error message and display
#------------------------------------------------------------------------------
if (defined $errorMessage[0])
{	display_errorMessage_SciMiner_CGI(\@errorMessage);
	print_end_html();
}else
{	# Create the URL
	print_end_html();
}








exit;




sub print_SciMiner_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>GO Detail</U></b></p>
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













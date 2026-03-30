#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                generateGeneListHTMLFull.cgi for SciMiner on the web
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
my $currentBaseDir		= param("currentBaseDir");
my $resultBaseDir		= param("resultBaseDir");
my $tmpValue			= param("tmpValue");
my $typeName			= param("typeName");
my $typeColumn			= param("typeColumn");
my $pathwayID			= param("pathwayID");
my $pathName			= param("pathName");

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


my $geneSummaryFileName	= '';
my %hugoIDCheck			= ();
my $hugoIDFound			= 0;

#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
if ( ((defined $currentBaseDir) && ($currentBaseDir ne "")) &&
	 ((defined $resultBaseDir) && ($resultBaseDir ne "")) &&
	 ((defined $tmpValue) && ($tmpValue ne "")) &&
	 ((defined $typeName) && ($typeName ne "")) &&
	 ((defined $typeColumn) && ($typeColumn ne "")) &&
	 ((defined $pathName) && ($pathName ne "")) &&
	 ((defined $pathwayID) && ($pathwayID ne ""))
   )
{	$geneSummaryFileName	= "FinalResults/$currentBaseDir/fullBGGeneSummary.html";
	
	#  First check the file to be created
	my $newHTMLToBeCreated	= "FinalResults/$currentBaseDir/Pathway/fullBGGeneSummary_".$pathwayID.'_'.$typeColumn.'.txt';
	
	print "<p class='titleBarName1'>$tmpValue targets for $pathName ($pathwayID) of \'$typeName\' section</p>";
	
	if (-f $newHTMLToBeCreated)
	{	#  Simply display the content
		open (HTMLFILE, $newHTMLToBeCreated);
		while(<HTMLFILE>)
		{	my $line = $_;
			print $line;
		}	close HTMLFILE;
	}else
	{	#  Load PMIDs to be extracted
		open (LIST, "FinalResults/$currentBaseDir/Pathway/SigTest_Pathway.hugoID");
		while (<LIST>)
		{	my $line = $_;
			if ($line =~ /^#/)
			{	next;
			}
			$line =~ s/\r|\n//g;
			my @tmpSplit = split (/\t/, $line);
					
			if ($tmpSplit[0] eq $pathwayID)
			{	#  Check the hugoID
				$hugoIDFound	= 1;
				if (defined $tmpSplit[$typeColumn])
				{	my @tmpSplit2	= split (/,/, $tmpSplit[$typeColumn]);
					foreach my $pmid (@tmpSplit2)
					{	$hugoIDCheck{$pmid}	= 1;
					}
				}
				last;
			}else
			{	#  Keep moving
			}
		}	close LIST;
	
		#  Check the status of hugoIDFound
		if (!$hugoIDFound)
		{	push @errorMessage, "No corresponding pathway ID found $pathwayID from $resultBaseDir...";
		}else
		{	# Now load the pmidList.html file and recreate a new htmlFild
			open (ORIHTML, $geneSummaryFileName) || return(-1);
			my @content	= <ORIHTML>;
			close ORIHTML;
			my $conString	= join (" ", @content);
			$conString		=~ s/\r|\n//g;
			
			my $finalResultString	= '<table border="1" width="590">';
			if ($conString	=~ /<table.*?<\/table>/)
			{	my $tmpMatch	= $&;
				while($tmpMatch	=~ /<tr.*?<\/tr>/)
				{	my $newMatch	= $&;
					$tmpMatch		= $';
					if ($newMatch =~ /class/)
					{	$finalResultString	.= $newMatch;
					}else
					{	if ($newMatch	=~ /hgnc_id=(\d+)/)
						{	if (defined $hugoIDCheck{$1})
							{	$finalResultString	.= $newMatch."\n";
							}
						}
					}
				}
			}
			
			$finalResultString	.= "</table><p>&nbsp;</p>\n";
			open (NEWHTML, ">".$newHTMLToBeCreated);
			print NEWHTML $finalResultString;
			print $finalResultString;
			close NEWHTML;
		}
	}
}else
{	push @errorMessage, "Some required parameters are not specified...";
	push @errorMessage, "currentBaseDir $currentBaseDir<br>";
	push @errorMessage, "resultBaseDir $resultBaseDir<br>";
	push @errorMessage, "tmpValue $tmpValue<br>";
	push @errorMessage, "typeName $typeName<br>";
	push @errorMessage, "typeColumn $typeColumn<br>";
	push @errorMessage, "pathwayID $pathwayID<br>";
	push @errorMessage, "pathName $pathName<br>";	
	
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
{   print "<p align=\"center\" class=\"pageName\"><b><U>Target Lists</U></b></p>
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













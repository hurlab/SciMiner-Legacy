#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                generatePMIDListFromMeSHHTMLSimple.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Created       : Aug 04, 2008
#  Desc:  This cgi accepts parameters from SciMiner and generate a file 
#         with selected MeSH Tree code
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
                        -script=>{-language	=>	'javascript1.2',
                        		  -src     	=>	'sciminer.js'},
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
my $meshDescID			= param("meshDescID");



my @errorMessage    	= ();
my @targetPMIDs     	= ();
my $queueSuccess    	= 0;
my $passCheckResult 	= 1;

my %hugoID2Symbol		= ();
my %meshDesc2ID			= ();
my %hugoID2Name			= ();
my @hugoIDs				= ();
my $hugoIDCnt			= 0;
my $hugoIDCntTotal		= 0;
my %hugoID2Occur		= ();
my %hugoID2Paper		= ();
my $MinTopCheck			= 'true';


my $pmidListFileName	= '';
my %pmidCheck			= ();
my $meshIDFound			= 0;

#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
if ( ((defined $currentBaseDir) && ($currentBaseDir ne "")) &&
	 ((defined $resultBaseDir) && ($resultBaseDir ne "")) &&
	 ((defined $tmpValue) && ($tmpValue ne "")) &&
	 ((defined $typeName) && ($typeName ne "")) &&
	 ((defined $typeColumn) && ($typeColumn ne "")) &&
	 ((defined $meshDescID) && ($meshDescID ne ""))
   )
{	$pmidListFileName	= "FinalResults/$resultBaseDir/pmidList.html";
	
	#  First check the file to be created
	my $newHTMLToBeCreated	= "FinalResults/$currentBaseDir/MeSH/pmidList_".$meshDescID.'_'.$typeColumn.'.txt';
	my $meshDesc			= '';
	
	
	if (-f $newHTMLToBeCreated)
	{	#  Simply display the content
		open (HTMLFILE, $newHTMLToBeCreated);
		while(<HTMLFILE>)
		{	my $line = $_;
			print $line;
		}	close HTMLFILE;
	}else
	{	#  Load PMIDs to be extracted
		my $pmidFileName	= '';
		if (-f "FinalResults/$currentBaseDir/MeSHCodeDistribution.pmid")
		{	$pmidFileName = "FinalResults/$currentBaseDir/MeSHCodeDistribution.pmid";
		}else
		{	$pmidFileName = "FinalResults/$currentBaseDir/MeSHEnrichmentResult.pmid";
		}
		
		open (LIST, $pmidFileName);
		while (<LIST>)
		{	my $line = $_;
			if ($line =~ /^#/)
			{	next;
			}
			$line =~ s/\r|\n//g;
			my @tmpSplit = split (/\t/, $line);
		
			if ($tmpSplit[0] eq $meshDescID)
			{	#  Check the meshTreeCode
				$meshIDFound	= 1;
				$meshDesc		= $tmpSplit[1];
				if (defined $tmpSplit[$typeColumn])
				{	my @tmpSplit2	= split (/,/, $tmpSplit[$typeColumn]);
					foreach my $pmid (@tmpSplit2)
					{	$pmidCheck{$pmid}	= 1;
					}
				}
				last;
			}else
			{	#  Keep moving
			}
		}	close LIST;
	
		#  Check the status of meshIDFound
		if (!$meshIDFound)
		{	push @errorMessage, "No corresponding MeSHTree ID found $meshDescID from $resultBaseDir...";
		}else
		{	# Now load the pmidList.html file and recreate a new htmlFild
			open (ORIHTML, "FinalResults/$resultBaseDir/pmidList.html") || return(-1);
			my @content	= <ORIHTML>;
			close ORIHTML;
			my $conString	= join (" ", @content);
			$conString		=~ s/\r|\n//g;
			
			my $finalResultString	= '<table border="1" width="850">';
			if ($conString	=~ /<table.*?<\/table>/)
			{	my $tmpMatch	= $&;
				while($tmpMatch	=~ /<tr.*?<\/tr>/)
				{	my $newMatch	= $&;
					
					$tmpMatch		= $';
					if ($newMatch =~ /class/)
					{	$finalResultString	.= $newMatch;
					}else
					{	if ($newMatch	=~ /^<tr>.*?>(\d+)<\/td>/)
						{	if (defined $pmidCheck{$1})
							{	$newMatch	=~ s/"pmid2ContDir/"FinalResults\/$resultBaseDir\/pmid2ContDir/;
								$newMatch	=~ s/"Docs/"FinalResults\/$resultBaseDir\/Docs/;
								$finalResultString	.= $newMatch."\n";
							}
						}
					}
				}
			}
			
			$finalResultString	.= "</table><p>&nbsp;</p>\n";
			open (NEWHTML, ">".$newHTMLToBeCreated);
			print NEWHTML "<p class='titleBarName1'>$tmpValue documents for $meshDesc of \'$typeName\' section</p>";
			print NEWHTML $finalResultString;
			close NEWHTML;
			print "<p class='titleBarName1'>$tmpValue documents for $meshDesc of \'$typeName\' section</p>";			
			print $finalResultString;
		}
	}
}else
{	
	push @errorMessage, "Some required parameters are not specified...";
	push @errorMessage, "currentBaseDir $currentBaseDir<br>";
	push @errorMessage, "resultBaseDir $resultBaseDir<br>";
	push @errorMessage, "tmpValue $tmpValue<br>";
	push @errorMessage, "typeName $typeName<br>";
	push @errorMessage, "typeColumn $typeColumn<br>";
	push @errorMessage, "meshDescID $meshDescID<br>";
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
{   print "<p align=\"center\" class=\"pageName\"><b><U>PMID Lists</U></b></p>
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


sub load_merged_summary_file_with_parameters
{   my $fileName            = shift;
    my $hugoID2SymbolRef    = shift;
    my $meshDesc2IDRef	= shift;
    my $hugoID2NameRef      = shift;
    my $hugoIDsRef          = shift;
    my $hugoIDCntRef        = shift;
    my $hugoIDCntTotalRef	= shift; 
    my $hugoID2OccurRef     = shift;
    my $hugoID2PaperRef     = shift;
    my $MinTopCheck			= shift;
    my $TotalPMID			= shift;
    my $minTopPaper			= shift;
    my $minTopMethod 		= shift;		

	$$hugoIDCntTotalRef		= 0;
	
	
	#  If not checking MinTop, then just read and process the file
	if (($MinTopCheck eq 'false') || (not defined $MinTopCheck))
	{	if (-f $fileName)
		{   open (FILENAME, $fileName) || print("Merged Summary file $fileName does not exist");
		    while(<FILENAME>)
		    {   my $line = $_;
		        $line =~ s/\r|\n//g;
		        my @tmpSplit = split(/\t/, $line);
		        $$hugoIDCntTotalRef++;
		        push @{$hugoIDsRef}, $tmpSplit[1]; 
		        if (not defined $$hugoID2SymbolRef{$tmpSplit[1]})
		        {   $$hugoID2SymbolRef{$tmpSplit[1]} = $tmpSplit[0];
		        }
		        if (not defined $$meshDesc2IDRef{$tmpSplit[0]})
		        {	$$meshDesc2IDRef{$tmpSplit[0]} = $tmpSplit[1];
		        }
		        if (not defined $$hugoID2NameRef{$tmpSplit[1]})
		        {   $$hugoID2NameRef{$tmpSplit[1]} = $tmpSplit[2];
		        }
		        $$hugoID2OccurRef{$tmpSplit[1]} = $tmpSplit[3];
		        $$hugoID2PaperRef{$tmpSplit[1]} = $tmpSplit[4];
		    }
		    close FILENAME;
		    $$hugoIDCntRef = scalar @{$hugoIDsRef};
		}
	}
	
	#  or, if checking MinTop, be sure to pay attention to the method
	else
	{	if ((not defined $minTopPaper) || ($minTopPaper eq ""))
		{   $minTopPaper		= 1;
		}
		
		if ((not defined $minTopMethod)  || ($minTopMethod eq ""))
		{	$minTopMethod		= 'MinPaperCount';
		}
	
		#  MinPaperCount Process
		if (($minTopMethod eq 'MinPaperCount') || ($minTopMethod eq 'MinPaperPercentage'))
		{	my $tmpThreshold	= $minTopPaper;
			if ($minTopMethod eq 'MinPaperPercentage')
			{	$tmpThreshold	= $TotalPMID*$minTopPaper/100;
			}
		
			if (-f $fileName)
			{   open (FILENAME, $fileName) || print("Merged Summary file $fileName does not exist");
				while(<FILENAME>)
				{   my $line = $_;
					$line =~ s/\r|\n//g;
				    my @tmpSplit = split(/\t/, $line);
				    $$hugoIDCntTotalRef++;
				
					# Only load targets with at least the minimum number of papers
				    if ($tmpSplit[4] < $tmpThreshold)
				    {   next;
				    }
				    
				    push @{$hugoIDsRef}, $tmpSplit[1]; 
				    if (not defined $$hugoID2SymbolRef{$tmpSplit[1]})
				    {   $$hugoID2SymbolRef{$tmpSplit[1]} = $tmpSplit[0];
				    }
				    if (not defined $$meshDesc2IDRef{$tmpSplit[0]})
				    {	$$meshDesc2IDRef{$tmpSplit[0]} = $tmpSplit[1];
				    }
				    if (not defined $$hugoID2NameRef{$tmpSplit[1]})
				    {   $$hugoID2NameRef{$tmpSplit[1]} = $tmpSplit[2];
				    }
				    $$hugoID2OccurRef{$tmpSplit[1]} = $tmpSplit[3];
				    $$hugoID2PaperRef{$tmpSplit[1]} = $tmpSplit[4];
				}
				close FILENAME;
				
				$$hugoIDCntRef = scalar @{$hugoIDsRef};
			}
		}
		
		#  TopPaperCount Process and others
		else 
		{	if (-f $fileName)
			{   open (FILENAME, $fileName) || print("Merged Summary file $fileName does not exist");
				my %symbol2Occurence			= ();
				my %symbol2Papers				= ();
				my @symbol						= ();
				my %symbol2Name					= ();
				my %symbol2ID					= ();
				while(<FILENAME>)
				{   my $line 					= $_;
				    $line 						=~ s/\r|\n//g;
				    my @tmp 					= split(/\t/, $line);
				    $$hugoIDCntTotalRef++;
					$symbol2Occurence{$tmp[0]} 	= $tmp[3];
					$symbol2Papers{$tmp[0]} 	= $tmp[4];
					push @symbol, 				$tmp[0];
					$symbol2Name{$tmp[0]}		= $tmp[2];
					$symbol2ID{$tmp[0]}			= $tmp[1];
				}	close FILENAME;
				
			    # Sorting by paper and occurrence 
				my %symbolPaperOccurrence = ();
				foreach my $symbol (@symbol)
				{	if (not defined $symbolPaperOccurrence{$symbol2Papers{$symbol}})
					{   my @newArray = ();
						push @newArray, $symbol;
						$symbolPaperOccurrence{$symbol2Papers{$symbol}} = \@newArray;
					}else
					{   push @{$symbolPaperOccurrence{$symbol2Papers{$symbol}}}, $symbol;
					}
				}
				my @newSortedSymbols = ();
				my @sortedCounts = sort {$b <=> $a} keys %symbolPaperOccurrence;
				foreach my $sortedCount ( @sortedCounts)
				{   my @countSortedSymbols = sort {$symbol2Occurence{$b} <=> $symbol2Occurence{$a}} @{$symbolPaperOccurrence{$sortedCount}};
					push @newSortedSymbols, @countSortedSymbols;
				}
				
				# Calculate the threshold
				if (($minTopMethod eq 'TopPaperCount') || ($minTopMethod eq 'TopPaperPercentage'))
				{	my $tmpThreshold	= $minTopPaper;
					if ($minTopMethod eq 'TopPaperCount')
					{	if ($minTopPaper > scalar (@newSortedSymbols))
						{	$tmpThreshold	= scalar (@newSortedSymbols);
						}
					}elsif ($minTopMethod eq 'TopPaperPercentage')
					{	$tmpThreshold	= int((scalar @newSortedSymbols)*$minTopPaper/100);
					} 
					
					for (my $i=0; $i < $tmpThreshold; $i++)
					{   push @{$hugoIDsRef}, $symbol2ID{$newSortedSymbols[$i]}; 
						if (not defined $$hugoID2SymbolRef{$symbol2ID{$newSortedSymbols[$i]}})
						{   $$hugoID2SymbolRef{$symbol2ID{$newSortedSymbols[$i]}} = $newSortedSymbols[$i];
						}
						if (not defined $$meshDesc2IDRef{$newSortedSymbols[$i]})
						{	$$meshDesc2IDRef{$newSortedSymbols[$i]} = $symbol2ID{$newSortedSymbols[$i]};
						}
						if (not defined $$hugoID2NameRef{$symbol2ID{$newSortedSymbols[$i]}})
						{   $$hugoID2NameRef{$symbol2ID{$newSortedSymbols[$i]}} = $symbol2Name{$newSortedSymbols[$i]};
						}
						$$hugoID2OccurRef{$symbol2ID{$newSortedSymbols[$i]}} = $symbol2Occurence{$newSortedSymbols[$i]};
						$$hugoID2PaperRef{$symbol2ID{$newSortedSymbols[$i]}} = $symbol2Papers{$newSortedSymbols[$i]};
					}
				}
				$$hugoIDCntRef = scalar @{$hugoIDsRef};
			}
		}
	}
}












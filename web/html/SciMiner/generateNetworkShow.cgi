#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                generateNetwork.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Created       : July 26, 2008
#  Last Modified : July 29, 2008
#  Desc:  This cgi accepts parameters from SciMiner and generate a file 
#         with official symbols to be used by Cytoscape MiMI plug-in
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
print $query->start_html(-title=>'Generate symbol list', 
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
                        


#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------
my $MinPaperMethod		= param("MinPaperMethod");
my $MinTopPaper			= param("MinTopPaper");
my $RelPath				= param("RelPath");
my $MerSumFileName		= param("MerSumFileName");
my $TotalPMID			= param("TotalPMID");
my $RandomNumber		= param("RandomNumber");


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


#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
if ( ((defined $MinPaperMethod) && ($MinPaperMethod ne "")) &&
	 ((defined $MinTopPaper) && ($MinTopPaper ne "")) &&
	 ((defined $RelPath) && ($RelPath ne "")) &&
	 ((defined $MerSumFileName) && ($MerSumFileName ne "")) &&
	 ((defined $TotalPMID) && ($TotalPMID ne "")))
{	load_merged_summary_file_with_parameters ($RelPath.$MerSumFileName, \%hugoID2Symbol, \%hugoSymbol2ID, \%hugoID2Name,
		                                      \@hugoIDs, \$hugoIDCnt, \$hugoIDCntTotal, \%hugoID2Occur, \%hugoID2Paper, 
		                                      $MinTopCheck, $TotalPMID, $MinTopPaper, $MinPaperMethod);
}else
{	push @errorMessage, "Cannot load original summary file";
}
	 
	 
#------------------------------------------------------------------------------
#	Generate Gene Symbol List File
#------------------------------------------------------------------------------
#  Check the number of hugoID
if ($hugoIDCnt < 2)
{	#  There is no way to create a network with less than 2 nodes
	push @errorMessage, "Total number of targets is less than 2";
	open (OUTFILE, ">".$RelPath.'Temp/'.$RandomNumber);
	close (OUTFILE);
}else
{	#  Generate temporary file
	open (OUTFILE, ">".$RelPath.'Temp/'.$RandomNumber);
	my $successCnt		= 0;
	foreach my $hugoid (@hugoIDs)
	{	if (defined $hugoID2Symbol{$hugoid})
		{	print OUTFILE $hugoID2Symbol{$hugoid}."\n";
			print $hugoID2Symbol{$hugoid}."<br>";
			$successCnt++;
		}
	}
	close OUTFILE;
	
	if ($successCnt < 2)
	{	push @errorMessage, "Total number of targets is less than 2";
	}else
	{	#  close the CGI
	}
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
    my $hugoSymbol2IDRef	= shift;
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
		        if (not defined $$hugoSymbol2IDRef{$tmpSplit[0]})
		        {	$$hugoSymbol2IDRef{$tmpSplit[0]} = $tmpSplit[1];
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
				    if (not defined $$hugoSymbol2IDRef{$tmpSplit[0]})
				    {	$$hugoSymbol2IDRef{$tmpSplit[0]} = $tmpSplit[1];
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
						if (not defined $$hugoSymbol2IDRef{$newSortedSymbols[$i]})
						{	$$hugoSymbol2IDRef{$newSortedSymbols[$i]} = $symbol2ID{$newSortedSymbols[$i]};
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












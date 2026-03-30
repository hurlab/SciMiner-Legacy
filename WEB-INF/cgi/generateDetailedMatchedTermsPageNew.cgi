#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                generateDetailedDatrchedTermsPage.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Created       : Aug 08, 2008
#  Desc:  This cgi accepts parameters from SciMiner and generate a detailed Matched_terms page
#
#******************************************************************************
BEGIN {
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;            
use Annotation::SciMiner;            
use CGI qw(:standard);
use CGI::Debug;
use DBI;
use SciMinerUI qw(print_topbar print_footer print_head_extras);

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
function ncbi_preview_window()
{	var url	= "https://www.ncbi.nlm.nih.gov/gene/?term=";
	var name = 'NCBI_Gene_Preview';
	var queryString = document.getElementsByName("matchString")[0].value;
	url = url + queryString + " AND Human[Orgn]";
	
	if (queryString.length > 0 )
	{   window.open(url, name);
	}else
	{   // do nothing.
	}
	
}   // ncbi_preview_window()



function closeSelfWindow()
{		window.opener = self;
		window.close();
}



function closeW()
{	var PROCESSEDStr	= document.getElementsByName("PROCESSED")[0].value;
		
	if (PROCESSEDStr == "YES")
	{	setTimeout("closeSelfWindow()", 10000);
	}
	
}  



function confirm_update(){
	var retval = window.confirm(' Are you sure to permanently UPDATE the mining result(s) ?');
	if (retval)
	{   document.getElementsByName('PerformUpdateDelete')[0].value 		= 'yes';
		document.getElementsByName('UpdateRecord')[0].value 			= 'update';
		document.getElementsByName('DeleteRecord')[0].value 			= '';
		document.form1.submit();
	}else
	{   document.getElementsByName('PerformUpdateDelete')[0].value 		= 'no';
	}
}


function confirm_delete(){
	var retval = window.confirm(' Are you sure to permanently DELETE the mining result(s) ?');
	if (retval)
	{   document.getElementsByName('PerformUpdateDelete')[0].value 		= 'yes';
		document.getElementsByName('UpdateRecord')[0].value 			= '';
		document.getElementsByName('DeleteRecord')[0].value 			= 'delete';
		document.form1.submit();
	}else
	{   document.getElementsByName('PerformUpdateDelete')[0].value 		= 'no';
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
my $hgncLinkURL         = "https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/";
my $ncbiGeneLink		= "https://www.ncbi.nlm.nih.gov/gene/";
my $ncbiGeneSearch		= "https://www.ncbi.nlm.nih.gov/gene/?term=";


#  Database Access Information
my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

#  ------------------------------------------------------------------------
#  Retrieve User Information from SciMinerDB
#  ------------------------------------------------------------------------
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                  return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

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
                        -script=>{-language	=>	'javascript1.2',
                           		  -src     	=>	'./sciminer.js',
                           		  -code		=> $JSCRIPT},
                        -style=>{-src=>['/SciMiner1.1/css/sciminer-modern.css'], -code=>$newStyle},
                        -onLoad=>'closeW()'
                        );
print_head_extras();
print_topbar();


print_SciMiner_Header();


#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------
my $hugoID				= param("hugoID");
my $fileNameBase		= param("fileNameBase");
my $occurCount			= param("occurCount");
my $paperCount			= param("paperCount");

my $hgncLinkURL         = "https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/";
my $ncbiGeneSearch		= "https://www.ncbi.nlm.nih.gov/gene/?term=";
my $ncbiGeneURL			= "https://www.ncbi.nlm.nih.gov/gene/";
my $ncbiPubMedURL       = "https://pubmed.ncbi.nlm.nih.gov/?term=";
my @errorMessage		= ();

#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
my $finalResultURL		= '';



#------------------------------------------------------------------------------
#	Check the transferred content
#------------------------------------------------------------------------------
if ( ((defined $hugoID) && ($hugoID ne "")) &&
	 ((defined $fileNameBase) && ($fileNameBase ne "")) &&
	 ((defined $occurCount) && ($occurCount ne "")) &&
	 ((defined $paperCount) && ($paperCount ne ""))
)
{
	#  Parameters are all set. 
	my $tmpFileName 	= "FinalResults/$fileNameBase/hugoID2ContDir/$hugoID.new.html";
	if (-f $tmpFileName)
	{	#open (FILE, $tmpFileName);
		#my @content	= <FILE>;
		#close FILE;
		#print @content;
		unlink ($tmpFileName);
		generate_hugoID2Cont ($hugoID, $fileNameBase, $occurCount, $paperCount, \@errorMessage, $dbh);
	}else
	{	generate_hugoID2Cont ($hugoID, $fileNameBase, $occurCount, $paperCount, \@errorMessage, $dbh);
	}
}else
{	push @errorMessage, "Required parameters are missing";
	push @errorMessage, "hugoID: $hugoID";
	push @errorMessage, "fileNameBase: $fileNameBase";
	push @errorMessage, "occurCount: $occurCount";
	push @errorMessage, "paperCount: $paperCount";
}























#------------------------------------------------------------------------------
#	Check error message and display
#------------------------------------------------------------------------------
if (defined $errorMessage[0])
{	display_errorMessage_SciMiner_CGI(\@errorMessage);
	print_end_html();
	exit;
}else
{	# Create the URL
	print_end_html();
	exit;
}











exit;






sub generate_hugoID2Cont
{   my $hugoID                      = shift;
	my $fileNameBase				= shift;
	my $occurCount					= shift;
	my $paperCount					= shift;
	my $errorMessageRef				= shift;
	my $dbh							= shift;
	
    my $cssURL						= '/SciMiner1.1/css/sciminer-modern.css';
    my $EDITIcon					= '/SciMiner1.1/SciMiner/Images/EDIT.jpg';
    
    my @targetSen2GeneID			= ();
    my $targetSen2GeneIDString		= '';
    
	#  First Load the sen2geneID file from the fileNameBase directory
	if (-f "FinalResults/$fileNameBase/SciMinerBase.Both.sen2geneID.txt")
	{	open (FILE, "FinalResults/$fileNameBase/SciMinerBase.Both.sen2geneID.txt");
		while(<FILE>)
		{	my $line = $_;
			$line 	=~ s/\r|\n//g;
			my @tmpSplit	= split (/\t/, $line);
			if ($tmpSplit[0] == $hugoID)
			{	@targetSen2GeneID	= split(/\,/, $tmpSplit[1]);
				$targetSen2GeneIDString	= $tmpSplit[1];
				last;
			}
		}
	}
	close FILE;
	
	if (not defined $targetSen2GeneID[0])
	{	push @{$errorMessageRef}, "No HUGO is defined in FinalResults/$fileNameBase/SciMinerBase.Both.sen2geneID.txt...";
		return();
	}
	

	#  Generate the content file
	open (RESULT, ">"."FinalResults/$fileNameBase/hugoID2ContDir/$hugoID.html");

	#  First retrieve gene information
	my $sth				= $dbh->prepare("SELECT approvedSymbol, approvedName, entrezGeneIDMappedData FROM gene WHERE hgncID = $hugoID");
	$sth->execute;
	my @row				= $sth->fetchrow_array;
	my $approvedSymbol	= '';
	my $approvedName	= '';
	my $entrezGeneIDMappedData	= '';
	if (defined $row[0])
	{	$approvedSymbol	= $row[0];
	}
	
	if (defined $row[1])
	{	$approvedName	= $row[1];
	}

	if (defined $row[2])
	{	$entrezGeneIDMappedData	= $row[2];
	}

	#  Retrieve user information
	$sth				= $dbh->prepare("SELECT userID, name FROM user");
	$sth->execute;
	my %userID2userName	= ();
	while(@row=$sth->fetchrow_array)
	{	if (defined $row[1])
		{	$userID2userName{$row[0]}	= $row[1];
		}
	}


	#  Generate HUGO ID Infor table
	my $outputString	= '';
	$outputString .= "<p class=\"pageName\" align=\"center\"> <b><a name=\"TOP\"></a>HUGO ID Detailed Result $hugoID</b></p>";


	# Generate table for the actual gene
    $outputString .= "<table border=\"1\" width=\"600\">
                    <tr class=\"titleBarName1\">
                        <th width=\"100\">
                            HUGO ID
                        </th>
                        <td width=\"500\">
                            <a href=\"$hgncLinkURL$hugoID\">$hugoID</a>
                        </td>
                    </tr>
                    <tr class=\"titleBarName1\">
                        <th width=\"100\">
                            Symbol
                        </th>
                        <td width=\"500\">
                  ";
	if ((defined $entrezGeneIDMappedData) && ($entrezGeneIDMappedData ne ""))
	{	$outputString .= "<a href=\"$ncbiGeneLink$entrezGeneIDMappedData\">$approvedSymbol</a>";
	}else
	{	$outputString .= "<a href=\"$ncbiGeneSearch".($approvedSymbol)." AND Human[Orgn]\">$approvedSymbol</a>";
	}
	
    $outputString .= "      </td>
                    </tr>
                    <tr class=\"titleBarName1\">
                        <th width=\"100\">
                            Name
                        </th>
                        <td width=\"500\">
                            $approvedName
                        </td>
                    </tr>
                    <tr class=\"titleBarName1\">
                        <th width=\"100\">
                            #Occurrence
                        </th>
                        <td width=\"500\">
                            $occurCount
                        </td>
                    </tr>
                    <tr class=\"titleBarName1\">
                        <th width=\"100\">
                            #Paper
                        </th>
                        <td width=\"500\">
                            $paperCount
                        </td>
                    </tr>                        
                 </table>
              <p>&nbsp;</p>
              <hr>
              ";        
                 
                 
                 
	$outputString .= "<table border=\"1\" width=\"960\">
                    <tr class=\"titleBarName1\">
                        <th width=\"70\">
                            PMID
                        </th>
                        <th width=\"125\">
                            Match String
                        </th>
                        <th width=\"125\">
                            Actual String
                        </th>
                        <th width=\"50\">
                            Score
                        </th>
                        <th width=\"430\">
                            Flanking text
                        </th>
                        <th width=\"100\">
                            Edited by
                        </th>
                        <th width=\"60\">
                            Edit
                        </th>
                    </tr>\n";



	#  Retrieve the actual sen2gene content
	$sth	= $dbh->prepare("SELECT * FROM sentence2gene WHERE sen2geneID in ($targetSen2GeneIDString) and hgncID = $hugoID");
	
	$sth->execute;
	while (@row = $sth->fetchrow_array)
	{	$outputString .= "<tr><td><a href=\"$ncbiPubMedURL$row[1]\">$row[1]</a></td><td>$row[6]</td><td>$row[7]</td><td>$row[9]</td><td>$row[10]</td>";
		if ((defined $row[22]) && ($row[22] ne ""))
		{	if  (defined $userID2userName{$row[22]})
			{	$outputString .= "<td>$userID2userName{$row[22]}</td>";
			}elsif ($row[22] != 0)
			{	$outputString .= "<td>UserID:$row[22]</td>";
			}else
			{	$outputString .= "<td>&nbsp;</td>";
			}
		}else
		{	$outputString .= "<td>&nbsp;</td>";
		}
		
		#  Edit Button
		$outputString .= "<td><a href=\"javascript:editSciMinerFindingFromMergedFileNew('$row[0]','$fileNameBase','$row[6]','$row[7]','$hugoID');\"><img src=\"$EDITIcon\"></a></td></tr>\n";
	}
	
        
    $outputString .= "</table>\n
        <p>&nbsp;</p>
        </body>
        </html>";
	print $outputString;
	print RESULT $outputString;
    close RESULT;
}   










sub print_SciMiner_Header
{   print "";
}


sub print_end_html
{   print_footer();
    print end_html;
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







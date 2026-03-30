#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                mergeQueries.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  First created : 09-07-2008
#  Desc:  This CGI merges multiple SciMiner query results into one
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

my $JSCRIPT=<<EOF;
function delete_query(queryID){
	var retval = window.confirm(' Are you sure to permanently delete this query ID ' + queryID + ' result ?');
	if (retval)
	{   document.getElementsByName('DeleteQuery')[0].value 		= 'delete';
		document.getElementsByName('DeleteAnalysis')[0].value 	= '';
		document.getElementsByName('DeleteID')[0].value 		= queryID;
		document.form2.submit();
	}else
	{   document.getElementsByName('DeleteQuery')[0].value = '';
	}
}
function openNewWindow (urlString)
{	window.open(urlString);
}
EOF


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
print $query->start_html(-title=>'SciMiner Query Result Merger CGI', 
                        -author=>'windysky.open@gmail.com',
                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
                        -script=> $JSCRIPT,
                        -BGCOLOR=>'#EAF4F4',
                        -style=>{-src=>['mm_health_nutr.css'],
                        		 -code=>$newStyle}
                        );

print "<script type='text/javascript' src='wz_tooltip.js'></script>"; 

#------------------------------------------------------------------------------
#  Initialize or assigne the parameters
#------------------------------------------------------------------------------
#  Transferred variables
my $email                       = param("email");
my $keyword						= param("keyword");
my $mergedName					= param("mergedName");
my $lastQueryNum				= param("lastQueryNum");
my $threshold					= param("threshold");
my @errorMessage                = ();
my $mergeStarted				= 0;


if ((defined param("DeleteQuery")) && (param("DeleteQuery") eq 'delete'))
{	if ((defined param('DeleteID')) && (param('DeleteID') ne ""))
	{	delete_query(param('DeleteID'));
	}
	print_Merger_Header();
	print_section1_form();
	print_default_query_list_section_header_only();
	$lastQueryNum = print_query_list_selection_from_SciMinerDB($email, $keyword);
	print_section_other_form($lastQueryNum);
	print_end_html();
	exit;


} elsif (defined param("RetrieveCompletedQuery"))
{	print_Merger_Header();
	print_section1_form();
	print_default_query_list_section_header_only();
	$lastQueryNum = print_query_list_selection_from_SciMinerDB($email, $keyword);
	print_section_other_form($lastQueryNum);
	print_end_html();
	exit;
}

elsif (defined param("Start Merge"))
{	##  Check passcode and retrieve the completed results
    if ((defined $lastQueryNum) && ($lastQueryNum >= 2))
    {	my $selectedMergeCount	= 0;
    	my @mergeQueryIDs		= ();
    	for (my $i=1; $i <= $lastQueryNum; $i++)
    	{	my $tmpString = 'checkbox'.$i;
    		if (defined param($tmpString))
    		{	# This query was checked for merging
    			$selectedMergeCount++;
    			push @mergeQueryIDs, $i;
    		}
    	}

		#  Start merge process    
		
		if (defined $threshold)
		{   if (!is_number($threshold))
			{   push @errorMessage, "Entered score threshold is not a numberic value.";
			}elsif ((not defined $mergedName) || ($mergedName eq ""))
			{	push @errorMessage, "Name for the merged query is not entered!";
			}elsif ($selectedMergeCount >= 2)
			{	$mergeStarted	= 1;
				print "<p class=\"titleBarName1\">&nbsp;Selected queries are now being merged.<BR>";
				print "This process may take a long time for large files.<BR>";
				print "If the page is time-out, please check 'completed' menu.<br><br></p>";
				process_merge_queries ($email, $mergedName, $threshold, \@mergeQueryIDs, $tmpLocalURL);
				print "<br><p class=\"titleBarName1\">Merging process completed. Please click <a href=\"completedLaunch.cgi\"><u>here</u></a> to see the result.<br></p>";
			}else
			{	push @errorMessage, "Not enough queries are selected for merging. Select at least two queries!";
			}
		}else
		{   push @errorMessage, "No score threshold is set.";
		}
    }else
    {	push @errorMessage, "Not enough queries are selected or available for merging.";
    }
}




#------------------------------------------------------------------------------
#  Process the analysis start process appropriately.
#------------------------------------------------------------------------------
# Check for any error message
if (defined $errorMessage[0])
{   print_Merger_Header();
    print_section1_form();
    print_section1_form_closing();
    display_errorMessage_SciMiner_CGI(\@errorMessage);
    print_default_query_list_section();
    print_section_other_form();
    print_end_html();
    exit;
}elsif (!$mergeStarted)
{   print_Merger_Header();
    print_section1_form();
    print_section1_form_closing();
    print_default_query_list_section();
    print_section_other_form();
   	print_end_html();
	exit;
}
exit;










#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------









  
print_end_html();
exit;



























#  -------------------------------------------------------------------------------------------------------



sub print_Merger_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>SciMiner Query Results Merger</U></b></p>
           ";

}

sub print_section1_form
{   print "<form name=\"form2\" action=\"mergeQueries.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
    			
			<p class=\"titleBarName1\"><br>(<b>Section_1</b>) Search your SciMiner mining results by<br>
			&nbsp;&nbsp;Query name : <INPUT TYPE='text' NAME='keyword' size=\"30\"> &nbsp;&nbsp;&nbsp;&nbsp;
		    <INPUT TYPE=\"HIDDEN\" NAME=\"email\" VALUE=\"".$email."\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteQuery\" VALUE=\"\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteAnalysis\" VALUE=\"\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteID\" VALUE=\"\">		    

 		    <input type='submit' name=\"RetrieveCompletedQuery\" value=\"Retrieve Completed Query\"> </p>
		   ";
    #
}


sub print_section1_form_closing
{	print "</form>
			";
}
#<p>You may click <i>'<b>Retrieve Completed Query</b>'
#    			</i> button to get the list of the currently available SciMiner results.</p>
    
    
sub print_default_query_list_section_header_only
{	my $tmpString = "<p class=\"titleBarName1\">(<b>Section_2</b>) Here are the list of your previous SciMiner results. (completed only)
			</p>
			<table border=\"1\">
			<tr class=\"tableHeader1\">
				<th width=\"50\" onmouseover=\"Tip('<b>Selected</b>: Check the queries to be merged')\" onmouseout=\"UnTip()\">
					Selected
				</th>
				<th width=\"70\" onmouseover=\"Tip('<b>Query Num</b>: A unique ID for each query')\" onmouseout=\"UnTip()\">
							Query Num
				</th>
				<th width=\"40\" onmouseover=\"Tip('<b>Query Mode</b>: Differnet mode of SciMiner<br><img src=&quot;Images/SCI.jpg&quot;>: Default SciMiner text mining mode<br><img src=&quot;Images/G2P.jpg&quot;>: NCBI Gene2PubMed mode<br><img src=&quot;Images/GR.jpg&quot;>: NCBI GeneRIF mode<br><img src=&quot;Images/MQ.jpg&quot;>: Merged queries mode')\" onmouseout=\"UnTip()\">
					Mode
				</th>
				<th width=\"300\" onmouseover=\"Tip('<b>Query Name</b>: The name given by user at the time of submission')\" onmouseout=\"UnTip()\">
					Name
				</th>
				<th width=\"80\" onmouseover=\"Tip('<b>Date</b>: The data on which the query was submitted')\" onmouseout=\"UnTip()\">
					Date
				</th>
				<th width=\"60\" onmouseover=\"Tip('<b>PMIDs</b>: Total number of PMIDs in the query')\" onmouseout=\"UnTip()\">
					PMIDs
				</th>
				<th width=\"60\" onmouseover=\"Tip('<b>Targets</b>: Total number of targets identified by SciMiner')\" onmouseout=\"UnTip()\">
					Targets
				</th>
				<th width=\"30\" onmouseover=\"Tip('<b>Link</b>: The SciMiner result page for this query')\" onmouseout=\"UnTip()\">
					Link
				</th>
				<th width=\"30\" onmouseover=\"Tip('<b>Del</b>: Delete the query')\" onmouseout=\"UnTip()\">
					Del
				</th>
			</tr>
			";
	return($tmpString);
}    			

sub print_default_query_list_section
{   print print_default_query_list_section_header_only();
	print "<tr>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
				<td>&nbsp;</td>
			</tr>
		</table>
";

}




sub print_query_list_selection_from_SciMinerDB
{   my $email               = shift;
	my $keyword				= shift;
	
	if ((not defined $keyword) || ($keyword !~ /\S/))
	{   $keyword			= "";
	}
    
    use DBI;
  
    #  Load working environment for ANNOTATION
    my %annoENV = anno_environmental_file_open ( );

    #  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

    #  Check email                      
    my $sql         = "SELECT userID FROM user where email like \"$email\"";
    
    my $sth         = $dbh->prepare($sql);
    $sth->execute();
    my @row         = $sth->fetchrow_array;
    my $userID      = $row[0];
                      
    if ((not defined $row[0]) || ($row[0] eq ""))
    {   print "<br><font color=\"red\">!ERROR! Your email <b>'$email'</b>is not registered. Please use your registered email only.<br>";
    	print_default_query_list_section();
    	return();
    }
    
    $sql         = "SELECT queryID, queryName, dateCreate, numPMID, numGene, resultURL, miningMode FROM query WHERE queryName like '\%$keyword\%' and status = 3 and deleted = 0 and userID = (SELECT userID FROM user WHERE email = \"$email\") ORDER BY queryID";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
    @row         = ();
    

    
    my %queryID2BaseName    = ();
    my $outputHTML  		= print_default_query_list_section_header_only();
    my $lastQueryNum		= 0;
    while(@row = $sth->fetchrow_array)
    {   $outputHTML .=      "<tr>
                            ";
        $outputHTML	.=		"<td><input type=\"checkbox\" name=\"checkbox$row[0]\" value=\"$row[0]\"></td>
        					";
        					
        #  Process Query Number
        if (not defined $row[0])
        {   $outputHTML .= "<td>&nbsp;</td>\n";
        }else
        {   $outputHTML .= "<td align=\"center\">$row[0]</td>\n";
        }
        
        #  Process Mode
        if (defined $row[6])
        {   if ($row[6] eq 'SciMinerMining')
			{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;Images/SCI.jpg&quot;>: Default SciMiner text mining mode')\" onmouseout=\"UnTip()\"><img src='Images/SCI.jpg'</td>\n";
			}elsif ($row[6] eq 'NCBIGene2PubMed')
			{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;Images/G2P.jpg&quot;>: NCBI Gene2PubMed mode')\" onmouseout=\"UnTip()\"><img src='Images/G2P.jpg'</td>\n";
			}elsif ($row[6] eq 'NCBIGeneRIF')
			{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;Images/GR.jpg&quot;>: NCBI GeneRIF mode')\" onmouseout=\"UnTip()\"><img src='Images/GR.jpg'</td>\n";
			}elsif ($row[6] eq 'MergedQuery')
			{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;Images/MQ.jpg&quot;>: Merged queries mode')\" onmouseout=\"UnTip()\"><img src='Images/MQ.jpg'</td>\n";
			}else
			{	$outputHTML .= "<td>$row[6]</td>\n";
			}
        }else
        {   $outputHTML .= "<td align=\"center\">&nbsp;</td>\n";
        }
        
        #  Process Name, date, PMIDs, Targets
        for (my $i=1; $i <=4; $i++)
        {   if (not defined $row[$i])
            {   $outputHTML .= "<td>&nbsp;</td>\n";
            }else
            {   $outputHTML .= "<td align=\"center\">&nbsp;$row[$i]</td>\n";
            }
        }
    
        # resultLink
        if (not defined $row[5])
        {   $outputHTML .= "<td>&nbsp;</td>\n";
        }else
        {   $outputHTML .= "<td>&nbsp;<a href=\"$row[5]\" onmouseover=\"Tip('Click here to see query ID #$row[0] result')\" onmouseout=\"UnTip()\"><img src=\"Images/R.jpg\"></a></td>\n";
        
            # Get the base name
            my @tmpSplit = split (/\//, $row[5]);
            $queryID2BaseName{$row[0]} = $tmpSplit[$#tmpSplit-1];
        }
        
        # Delete button
        $outputHTML .= "<td>&nbsp;<a href=\"#\" onclick=\"delete_query($row[0])\" onmouseover=\"Tip('Click here to delete query ID #$row[0] result')\" onmouseout=\"UnTip()\"><img src=\"Images/D.jpg\"></a></td>\n";
        $outputHTML .= "</tr>
                            ";
		$lastQueryNum	= $row[0];
    }
    
    $outputHTML .= " </table>
    				 
    ";
    
    print $outputHTML;
    return ($lastQueryNum);
}




sub print_section_other_form
{   my $lastQueryNum		= shift;


	#<form name=\"form1\" action=\"$annoENV{SciMinerServerURL}SciMiner/FuncAnal.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
    print "<br>
    	   <table border=\"1\">
				<tr>
					<td width=\"450\"  class=\"tableHeader1\">
						Enter the name for the merged query rsults
					</td>	
					<td width=\"200\">
						<input type=\"text\" name=\"mergedName\" size=\"32\" value=\"\" style=\"text-align: right\">
					</td>
				</tr>
	
				<tr>
					<td width=\"450\"  class=\"tableHeader1\">
						Enter a new confidence score threshold<br>
						>=0.1: minimum default, >=0.3: moderate confidence, >=0.6: high confidence<br>
						<a onclick=\"openNewWindow('Files/ConfidenceScoreHelp.html');\" onmouseover=\"Tip('Click here to view more help on score threshold.')\" onmouseout=\"UnTip()\"><b><u>more on scores</u></b></a>
					</td>	
					<td width=\"200\">
						<input type=\"text\" name=\"threshold\" size=\"32\" value=\"0.1\" style=\"text-align: right\">
					</td>
				</tr>
			</table>    

			<INPUT TYPE=\"HIDDEN\" NAME=\"email\" VALUE=\"$email\">";
	if (defined $lastQueryNum)
	{	print "<INPUT TYPE=\"HIDDEN\" NAME=\"lastQueryNum\" VALUE=\"$lastQueryNum\">";
	}else
	{	print "";
	}
	print 	"<p>&nbsp;</p>
			<p><input type='submit' name=\"Start Merge\" value=\"Start Merge\"> <input type=\"reset\" name=\"reset form\"></p>
			</form>";

}




sub print_end_html
{   print end_html;
    exit;
}


sub check_email_format
{   my $email                   = shift;
    my $errorMessageRef         = shift;    
    
    #  Check email format
    if ((not defined $email) || ($email !~ /\S/))
    {   push @{$errorMessageRef}, "E-mail is empty.";
    }else
    {   if ($email =~ /^\w+\@.*\..*/)
        {   # This is a profer email address
        }else
        {   push @{$errorMessageRef}, "E-mail format is unacceptable.";
        }
    }
}



sub check_passcode
{   my $email                   = shift;
    my $passCode                = shift;
    my $errorMessageRef         = shift; 
    
    if ((not defined $passCode) || ($passCode !~ /\S/))
    {   push @{$errorMessageRef}, "Your pass code is empty.";
        return(-1);
    }else
    {   my $passCheckResult = SciMiner_email_password_check ($email, $passCode);
        # 1: same 0: different
        if (!$passCheckResult)
        {   push @{$errorMessageRef}, "Your passcode is not correct. Check it again or contact admin for help";
        }
        return($passCheckResult);
    }
}


#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                analysis.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Last Modified : Nov, 27, 2007
#  Desc:  This cgi accepts the start page for SciMiner Post-Mining Analysis 
#         on the web
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
use SciMinerUI qw(print_topbar print_footer print_head_extras);
#use warnings;
use strict;


my $JSCRIPT=<<EOF;
function delete_query(queryID){
	var retval = window.confirm(' Are you sure to permanently delete this query ID ' + queryID + ' result ?');
	if (retval)
	{   document.getElementsByName('DeleteQuery')[0].value 		= 'delete';
		document.getElementsByName('DeleteID')[0].value 		= queryID;
		document.form2.submit();
	}else
	{   document.getElementsByName('DeleteQuery')[0].value = '';
	}
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
#print header,start_html(-title=>'SciMiner CGI', 
#                        -author=>'windysky.open@gmail.com',
#                        -meta=>{'keywords'=>'Junguk Hur SciMiner text mining text-mining bioinformatics',
#                                'copyright'=>'copyright 2007 Junguk Hur'},
#                        -BGCOLOR=>'#EAF4F4');
print header;
print $query->start_html(-title=>'SciMiner Post-Mining Analysis CGI', 
                        -author=>'windysky.open@gmail.com',
                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
                        -script=> $JSCRIPT,
                        -style=>{-src=>['/SciMiner1.1/css/sciminer-modern.css'],
                        		 -code=>$newStyle}
                        		 );
print_head_extras();
print_topbar();


print "<script type='text/javascript' src='wz_tooltip.js'></script>";


#------------------------------------------------------------------------------
#  Initialize or assigne the parameters
#------------------------------------------------------------------------------
#  Transferred variables
my $email                       = param("email");
my $minPaper					= '';

#my $passCode                   = param("passCode");
my $keyword						= param("keyword");

my $targetQueryNumber           = param("queryNumber");
my $bgQueryNumber               = param("BGQueryNumber");
   $targetQueryNumber           =~ s/\s+//g;
   $bgQueryNumber               =~ s/\s+//g;
my $PValueThreshold             = param("PValueThreshold");   
my $GeneEnrichmentCheck         = param("GeneEnrichmentCheck");
if (not defined $GeneEnrichmentCheck)
{   $GeneEnrichmentCheck        = "off";
}
my $GOEnrichmentCheck           = param("GOEnrichmentCheck");
if (not defined $GOEnrichmentCheck)
{   $GOEnrichmentCheck          = "off";
}
my $MeSHEnrichmentCheck         = param("MeSHEnrichmentCheck");
if (not defined $MeSHEnrichmentCheck)
{   $MeSHEnrichmentCheck        = "off";
}
my $PathwayEnrichmentCheck      = param("PathwayEnrichmentCheck");
if (not defined $PathwayEnrichmentCheck)
{   $PathwayEnrichmentCheck     = "off";
}
my $PPICheck                    = param("PPICheck");
if (not defined $PPICheck)
{   $PPICheck                   = "off";
}

my $GeneEnrichmentSelection     = param("GeneEnrichment");
my $GOEnrichmentSelection       = param("GOEnrichment");
my $MeSHEnrichmentSelection     = param("MeSHEnrichment");
my $PathwayEnrichmentSelection  = param("PathwayEnrichment");
my $PPISelection                = param("PPI");

#  Min/Top Papers
my $MinPaperMethodTG			= param("MinPaperMethodTG");
my $MinTopPaperTG				= 1;
#if (defined param("MinTopPaperTG"))
#{	$MinTopPaperTG				= param("MinTopPaperTG");
#}
my $MinPaperMethodBG			= param("MinPaperMethodBG");
my $MinTopPaperBG				= 1;
#if (defined param("MinTopPaperBG"))
#{	$MinTopPaperBG				= param("MinTopPaperBG");
#}

my $TGListFile					= param("TGListFile");
   $TGListFile					=~ s/.*[\/\\](.*)/$1/;
my $TGListFileUploadFileHandle	= upload("TGListFile");
my $TGListFileContent			= join(",", <$TGListFileUploadFileHandle>);
   $TGListFileContent			=~ s/\r|\n//g;
   

my $BGListFile					= param("BGListFile");
   $BGListFile					=~ s/.*[\/\\](.*)/$1/;
my $BGListFileUploadFileHandle	= upload("BGListFile");
my $BGListFileContent			= join(",", <$BGListFileUploadFileHandle>);
   $BGListFileContent			=~ s/\r|\n//g;


#  Local variables
my @errorMessage                = ();
my @targetPMIDs                 = ();
my $queueSuccess                = 0;
my $analysisStart               = 0;
my $checkPassCodeResult         = '';

#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------

if ((defined param("DeleteQuery")) && (param("DeleteQuery") eq 'delete'))
{	print_FuncAnal_Header();
    print_section1_form();
    
	if ((defined param('DeleteID')) && (param('DeleteID') ne ""))
	{	delete_query(param('DeleteID'));
	}
	
    print_query_list_selection_from_SciMinerDB($email, $keyword);
	print_section_other_form();
    print_end_html();
    exit;
}


if (defined $PValueThreshold)
{   if (!is_number($PValueThreshold))
    {   push @errorMessage, "Entered P-value is not a numberic value.";
    }
    if ($PValueThreshold eq "")
    {   $PValueThreshold = 0;
    }
}else
{   push @errorMessage, "No P-value threshold is set.";
}

if (defined param("RetrieveCompletedQuery"))
{   print_FuncAnal_Header();
    print_section1_form();
    
    ##  Check passcode and retrieve the completed results
    #$checkPassCodeResult = check_passcode($email, $passCode, \@errorMessage);
    #if ($checkPassCodeResult == 1)   
    #{   #  Passcode is correct, Generate the list section
    #    print_query_list_selection_from_SciMinerDB($email);
    #}else
    #{   #  Printout the default list section
    #    display_errorMessage_SciMiner_CGI(\@errorMessage);
    #    print_default_query_list_section();
    #} 
    
    print_query_list_selection_from_SciMinerDB($email, $keyword);
    print_section_other_form();
    print_end_html();
    exit;
    
}elsif (defined param("Start Analysis"))
{   ##  Check passcode and retrieve the completed results
    #$checkPassCodeResult = check_passcode($email, $passCode, \@errorMessage);
     
    #  Check if target query number is set
    if ((not defined $targetQueryNumber) || ($targetQueryNumber eq ""))
    {   push @errorMessage, "Target query number is empty.";
    }elsif ($targetQueryNumber =~ /\D/)
    {   push @errorMessage, "Target query number contains non-numeric characgter.";
    }else
    {   check_query_number_validity ("target", $targetQueryNumber, \@errorMessage);
    }
    

    #  Check the minimum number of paper threshold
    if ((not defined param("MinTopPaperTG")) || (param("MinTopPaperTG") eq "") ||
    	(param("MinTopPaperTG") <= 0))   # || (param("MinTopPaperTG") =~ /\D/))
    {	push @errorMessage, "The min/top #/% of papers for target query is not properly defined.";
    }else
    {	$MinTopPaperTG	= param("MinTopPaperTG");
    	if (!is_number($MinTopPaperTG))
    	{	push @errorMessage, "$MinTopPaperTG is not a numeric value.";
    	}elsif ((($MinPaperMethodTG eq 'MinPaperPercentage') || ($MinPaperMethodTG eq 'TopPaperPercentage')) &&
    			($MinTopPaperTG > 100))
    	{	push @errorMessage, "$MinTopPaperTG is more than 100% percent.";
    	}
    }
    	
    if ((not defined param("MinTopPaperBG")) || (param("MinTopPaperBG") eq "") ||
    	(param("MinTopPaperBG") <= 0))   # || (param("MinTopPaperBG") =~ /\D/))
    {	push @errorMessage, "The min/top #/% of papers for background query is not properly defined.";
    }else
    {	$MinTopPaperBG	= param("MinTopPaperBG");
    	if (!is_number($MinTopPaperBG))
    	{	push @errorMessage, "$MinTopPaperBG is not a numeric value.";
    	}elsif ((($MinPaperMethodBG eq 'MinPaperPercentage') || ($MinPaperMethodBG eq 'TopPaperPercentage')) &&
    			($MinTopPaperBG > 100))
    	{	push @errorMessage, "$MinTopPaperBG is more than 100% percent.";
    	}
    }	
    
    #  Check if none of the module has been checked
    if ((!$GeneEnrichmentCheck) && (!$GOEnrichmentCheck) && (!$MeSHEnrichmentCheck) && (!$PathwayEnrichmentCheck) && (!$PPICheck))
    {   push @errorMessage, "None of the analysis module has been selected."; 
    }else
    {   #  If any of the selected modules is set to use selected background set
        if ((($GeneEnrichmentCheck eq "on") && ($GeneEnrichmentSelection eq 'Selected')) || 
            (($GOEnrichmentCheck eq "on") && ($GOEnrichmentSelection eq 'Selected')) || 
            (($MeSHEnrichmentCheck eq "on") && ($MeSHEnrichmentSelection eq 'Selected')) ||
            (($PathwayEnrichmentCheck eq "on") && ($PathwayEnrichmentSelection eq 'Selected')) || 
            (($PPICheck eq "on") && ($PPISelection eq 'Selected')))
        {   #  Check if background query number is set
            if ((not defined $bgQueryNumber) || ($bgQueryNumber eq ""))
            {   push @errorMessage, "Background query number is empty.";
            }elsif ($bgQueryNumber =~ /\D/)
            {   push @errorMessage, "Background query number contains non-numeric characgter.";
            }else
            {   check_query_number_validity ("backgroud", $bgQueryNumber, \@errorMessage);
            }
        }
    }
    
    #  Mark this for possible candidate for analysis start
    $analysisStart = 1;
}else
{   #  No button is clicked. Print out default forms
    print_FuncAnal_Header();
    print_section1_form();
    print_default_query_list_section();
    print_section_other_form();
    print_end_html();
    exit;
}







#------------------------------------------------------------------------------
#  Process the analysis start process appropriately.
#------------------------------------------------------------------------------
# Check for any error message
if (defined $errorMessage[0])
{   print_FuncAnal_Header();
    print_section1_form();
    display_errorMessage_SciMiner_CGI(\@errorMessage);
    print_default_query_list_section();
    print_section_other_form();
    print_end_html();
    exit;
}else
{   my ($status, $message) = process_post_mining_analysis_queue ($email, $targetQueryNumber, $bgQueryNumber, 
        $GeneEnrichmentCheck, $GOEnrichmentCheck, $MeSHEnrichmentCheck, $PathwayEnrichmentCheck, $PPICheck,
        $GeneEnrichmentSelection, $GOEnrichmentSelection, $MeSHEnrichmentSelection, $PathwayEnrichmentSelection, 
        $PPISelection, $PValueThreshold, $tmpLocalURL, $MinPaperMethodTG, $MinTopPaperTG, $MinPaperMethodBG, $MinTopPaperBG,
        $TGListFileContent, $BGListFileContent);
    if (! $status)
    {   print "<br>$message<br>";
    }
}



  
print_end_html();
exit;



























#  -------------------------------------------------------------------------------------------------------



sub print_FuncAnal_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>SciMiner Post-Mining Analysis</U></b></p>
	<p class=\"titleBarName1\">(<b>Instruction</b>): Click <a href=\"Files/SciMiner_User_Manual.pdf\"><b>HERE</b></a> for detailed help or move mouse pointer around to get a quick tip.<br> &nbsp;&nbsp;&nbsp;1) Click <b>'Retrieve Completed Query'</b> to retrieve currently available SciMiner results.<br> &nbsp;&nbsp;&nbsp;2) Enter query ID for tested (and background set) <br> &nbsp;&nbsp;&nbsp;3) Select analysis modules and click <b>'Start Analysis'</b> to submit the analysis.</p>
           ";

}

sub print_section1_form
{   print "<form name=\"form2\" action=\"analysis.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
   		   <p class=\"titleBarName1\">(<b>Section_1</b>) Search your SciMiner mining results by<br>
			&nbsp;&nbsp;Query name : 
			<INPUT TYPE='text' NAME='keyword' value=\"$keyword\" size=\"30\" onmouseover=\"Tip('Limit your search by partial query name')\" onmouseout=\"UnTip()\"> &nbsp;&nbsp;&nbsp;&nbsp;
		  	<INPUT TYPE=\"HIDDEN\" NAME=\"email\" VALUE=\"$email\">
  	    	<INPUT TYPE=\"HIDDEN\" NAME=\"DeleteQuery\" VALUE=\"\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteID\" VALUE=\"\">		    
		  	<INPUT type='submit' name=\"RetrieveCompletedQuery\" value=\"Retrieve Completed Query\" onmouseover=\"Tip('Click to retrieve completed SciMiner search queries')\" onmouseout=\"UnTip()\"> 
			</p>
		   </form>";
    #
}

#<p>You may click <i>'<b>Retrieve Completed Query</b>'
#    			</i> button to get the list of the currently available SciMiner results.</p>
    
    
sub print_default_query_list_section_header_only
{	my $tmpString = "<p class=\"titleBarName1\">(<b>Section_2</b>) Here are the list of your previous SciMiner results. (completed only)
			</p>
			<table border=\"1\">
			<tr class=\"tableHeader1\">
				<th width=\"70\" onmouseover=\"Tip('<b>Query Num</b>: A unique ID for each query')\" onmouseout=\"UnTip()\">
		    		Query Num
				</th>
				<th width=\"40\" onmouseover=\"Tip('<b>Query Mode</b>: Differnet mode of SciMiner<br><img src=&quot;/SciMiner1.1/SciMiner/Images/SCI.jpg&quot;>: Default SciMiner text mining mode<br><img src=&quot;/SciMiner1.1/SciMiner/Images/G2P.jpg&quot;>: NCBI Gene2PubMed mode<br><img src=&quot;/SciMiner1.1/SciMiner/Images/GR.jpg&quot;>: NCBI GeneRIF mode<br><img src=&quot;/SciMiner1.1/SciMiner/Images/MQ.jpg&quot;>: Merged queries mode')\" onmouseout=\"UnTip()\">
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
    
    $sql         			= "SELECT queryID, miningMode, queryName, dateCreate, numPMID, status, numGene, resultURL FROM query WHERE queryName like '\%$keyword\%' and deleted = 0 and userID = (SELECT userID FROM user WHERE email = \"$email\") ORDER by queryID";
    $sth        			= $dbh->prepare($sql);
    $sth->execute();
    @row         			= ();
    my @fullCont			= ();
    
    my %queryID2BaseName    = ();
    my $outputHTML  		= print_default_query_list_section_header_only();
    my $lastSuccQueryID		= 0;
    my $lastSuccG2PID		= 0;
    my $lastSuccGR			= 0;
    
    while(my @newrow = $sth->fetchrow_array)
    {	push @fullCont, \@newrow;
    	if (($newrow[1] eq 'SciMinerMining') && (($newrow[5] == 2) || ($newrow[5] == 3)))
    	{	$lastSuccQueryID	= $newrow[0];
    	}
    	if (($newrow[1] eq 'NCBIGene2PubMed') && (($newrow[5] == 2) || ($newrow[5] == 3)))
    	{	$lastSuccG2PID		= $newrow[0];
    	}
    	if (($newrow[1] eq 'NCBIGeneRIF') && (($newrow[5] == 2) || ($newrow[5] == 3)))
    	{	$lastSuccGR			= $newrow[0];
    	}
    }
    
    for (my $i=0; $i <= $#fullCont; $i++)
    {	$outputHTML .=      "<tr>
                            ";
		@row	= @{$fullCont[$i]};
        for (my $i=0; $i <=4; $i++)
        {   if (not defined $row[$i])
            {   $outputHTML .= "<td>&nbsp;</td>\n";
            }else
            {   if ($i == 1)
		    	{	if ($row[1] eq 'SciMinerMining')
		    		{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/SCI.jpg&quot;>: Default SciMiner text mining mode')\" onmouseout=\"UnTip()\"><img src='/SciMiner1.1/SciMiner/Images/SCI.jpg'></td>\n";
		    		}elsif ($row[1] eq 'NCBIGene2PubMed')
		    		{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/G2P.jpg&quot;>: NCBI Gene2PubMed mode')\" onmouseout=\"UnTip()\"><img src='/SciMiner1.1/SciMiner/Images/G2P.jpg'></td>\n";
		    		}elsif ($row[1] eq 'NCBIGeneRIF')
		    		{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/GR.jpg&quot;>: NCBI GeneRIF mode')\" onmouseout=\"UnTip()\"><img src='/SciMiner1.1/SciMiner/Images/GR.jpg'></td>\n";
		    		}elsif ($row[1] eq 'MergedQuery')
		    		{	$outputHTML .= "<td onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/MQ.jpg&quot;>: Merged queries mode')\" onmouseout=\"UnTip()\"><img src='/SciMiner1.1/SciMiner/Images/MQ.jpg'></td>\n";
		    		}else
		    		{	$outputHTML .= "<td>$row[$i]</td>\n";
		    		}
		    	}else
		    	{	$outputHTML .= "<td>$row[$i]</td>\n";
		    	}
            }
        }
    
    	# numGene
		if ($row[5] == 1)
		{	#  Status == 1 ==> qeued but not processed yet.
			if ($row[0] < $lastSuccQueryID)
			{	$outputHTML .= "<td><a href=\"#\" onclick=\"delete_query($row[0])\" onmouseover=\"Tip('Click here to delete queued query ID #$row[0]')\" onmouseout=\"UnTip()\">Failed</a></td>\n";
			}else
			{	$outputHTML .= "<td><a href=\"#\" onclick=\"delete_queued_query($row[0])\" onmouseover=\"Tip('Click here to cancel queued query ID #$row[0]')\" onmouseout=\"UnTip()\">Queued</a></td>\n";
			}
		}elsif ($row[5] == 2)
		{	$outputHTML .= "<td>Processing</td>\n";	
		}else
		{	$outputHTML .= "<td>$row[6]</td>\n";
		}
		
		
        # resultLink
        if (not defined $row[7])
        {   $outputHTML .= "<td>&nbsp;</td>\n";
        }else
        {   $outputHTML .= "<td><a href=\"/SciMiner1.1/$row[7]\" onmouseover=\"Tip('Click here to see query ID #$row[0] result')\" onmouseout=\"UnTip()\"><img src=\"/SciMiner1.1/SciMiner/Images/R.jpg\"></a></td>\n";
        
            # Get the base name
            my @tmpSplit = split (/\//, $row[7]);
            $queryID2BaseName{$row[0]} = $tmpSplit[$#tmpSplit-1];
        }
        
        # Delete button
        $outputHTML .= "<td><a href=\"#\" onclick=\"delete_query($row[0])\" onmouseover=\"Tip('Click here to delete query ID #$row[0] result')\" onmouseout=\"UnTip()\"><img src=\"/SciMiner1.1/SciMiner/Images/D.jpg\"></a></td>\n";
        $outputHTML .= "</tr>
                            ";
    }
    
    $outputHTML .= " </table>
    ";
    
    print $outputHTML;
    return (\%queryID2BaseName);
}






sub print_section_other_form
{   #<form name=\"form1\" action=\"$annoENV{SciMinerServerURL}SciMiner/FuncAnal.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
    print "<br><form name=\"form1\" action=\"analysis.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
			<table border=\"0\">
			<tr>
				<td width=\"150\"  class=\"tableHeader1\" onmouseover=\"Tip('Select the query number you would like to run the analysis on.<br>Identified targets of the selected query')\" onmouseout=\"UnTip()\">
					Query result to be <b>tested</b>
				</td>	
				<td width=\"60\" onmouseover=\"Tip('Enter your test query number')\" onmouseout=\"UnTip()\">
					<input type=\"text\" name=\"queryNumber\" size=\"3\" value=\"\" style=\"text-align: right\">
				</td>
				<td width=\"10\">
					&nbsp;
				</td>
				<td width=\"80\" onmouseover=\"Tip('You can limit your targets in the analysis <br>by number of papers per target and by a list file')\" onmouseout=\"UnTip()\">
					<b>Limit targets by</b>
				</td>		
				<td width=\"100\"  class=\"tableHeader1\" onmouseover=\"Tip('Only identified targets satisfying the following criteria will be used.<br><br><b>Minimum # Paper</b>: Minimum number of papers per target<br>&nbsp;&nbsp;eg) Any target identified from 1 or 2 papers will be excluded <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;when the threshold is set to 3<br><b>Minimum % Paper</b>: Minimum percentage of papers per target<br><b>Top # Target</b>: Only the top # ranked targets<br><b>Top % Target</b>: Only the top % percentage ranked targets')\" onmouseout=\"UnTip()\">
					<select name=\"MinPaperMethodTG\" size=\"1\">
					    <option selected value=\"MinPaperCount\">Minimum # Paper</option>
					    <option value=\"MinPaperPercentage\">Minimum % Paper</option>
					    <option value=\"TopPaperCount\">Top # Target</option>
					    <option value=\"TopPaperPercentage\">Top % Target</option>
					</select>
				</td>
				<td width=\"30\"  class=\"tableHeader1\">
					<input type=\"text\" name=\"MinTopPaperTG\" size=\"2\" value=\"$MinTopPaperTG\" style=\"text-align: right\">
				</td>
				<td width=\"60\"  class=\"tableHeader1\" style=\"text-align: right\" onmouseover=\"Tip('Target list can further be limited by <br> <b>a user provided list (official symbols)</b><br>')\" onmouseout=\"UnTip()\">
					and by list
				</td>
				<td width=\"50\" class=\"tableHeader1\" onmouseover=\"Tip('Select a file containing a list of <b>offcial symbols</b>')\" onmouseout=\"UnTip()\">
					<INPUT TYPE='file' NAME='TGListFile' size=\"10\">
				</td>	
			</tr>
			<tr>
				<td class=\"tableHeader1\">
					Query result as <b>background</b>
				</td>	
				<td class=\"tableHeader1\" onmouseover=\"Tip('Enter your background query number')\" onmouseout=\"UnTip()\">
					<input type=\"text\" name=\"BGQueryNumber\" size=\"3\" value=\"\" style=\"text-align: right\">
				</td>
				<td class=\"tableHeader1\">
					&nbsp;
				</td>	
				<td onmouseover=\"Tip('You can limit your targets in the analysis <br>by number of papers per target and by a list file')\" onmouseout=\"UnTip()\">
					<b>Limit targets by</b>
				</td>			
				<td class=\"tableHeader1\" onmouseover=\"Tip('Only identified targets satisfying the following criteria will be used.<br><br><b>Minimum # Paper</b>: Minimum number of papers per target<br>&nbsp;&nbsp;eg) Any target identified from 1 or 2 papers will be excluded <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;when the threshold is set to 3<br><b>Minimum % Paper</b>: Minimum percentage of papers per target<br><b>Top # Target</b>: Only the top # ranked targets<br><b>Top % Target</b>: Only the top % percentage ranked targets')\" onmouseout=\"UnTip()\">
					<select name=\"MinPaperMethodBG\" size=\"1\">
					    <option selected value=\"MinPaperCount\">Minimum # Paper</option>
					    <option value=\"MinPaperPercentage\">Minimum % Paper</option>
					    <option value=\"TopPaperCount\">Top # Target</option>
					    <option value=\"TopPaperPercentage\">Top % Target</option>
					</select>
				</td>
				<td class=\"tableHeader1\">
					<input type=\"text\" name=\"MinTopPaperBG\" size=\"2\" value=\"$MinTopPaperBG\" style=\"text-align: right\">
				</td>
				<td width=\"30\"  class=\"tableHeader1\" style=\"text-align: right\" onmouseover=\"Tip('Target list can further be limited by <br> <b>a user provided list (official symbols)</b><br>')\" onmouseout=\"UnTip()\">
					and by list
				</td>
				<td class=\"tableHeader1\" onmouseover=\"Tip('Select a file containing a list of <b>offcial symbols</b>')\" onmouseout=\"UnTip()\">
					<INPUT TYPE='file' NAME='BGListFile' size=\"10\">
				</td>
			</tr>
			<tr>
				<td class=\"tableHeader1\">
					<b>P-value</b> for significance test
				</td>	
				<td onmouseover=\"Tip('Enter desired p-value threshold.')\" onmouseout=\"UnTip()\">
					<input type=\"text\" name=\"PValueThreshold\" size=\"3\" value=\"0.05\" style=\"text-align: right\">
				</td>
				<td>
					&nbsp;
				</td>
				<td>
					&nbsp;
				</td>			
				<td>
					Significant&nbsp;&nbsp;p-values&nbsp;&nbsp;will 
				</td>
				<td>
					be in
				</td>
				<td>
					<font color='red'>red</font> in result.
				</td>
			</tr>
		</table>    
			
	  
		<INPUT TYPE=\"HIDDEN\" NAME=\"email\" VALUE=\"$email\">

		
		<p class=\"titleBarName1\">
		(<b>Section3</b>) Select functional analysis modules to run.
		</p>


			<table border=\"1\" width=\"760\">
				<tr class=\"tableHeader1\">
				    <th width=\"20\" align=\"center\" valign=\"middle\">&nbsp;</th>
				    <th width=\"250\" align=\"center\" valign=\"middle\" onmouseover=\"Tip('Available Post-Mining Analysis modules')\" onmouseout=\"UnTip()\"><b>Analysis module</b></th>
				    <th width=\"110\" align=\"center\" valign=\"middle\" onmouseover=\"Tip('Statistical methods used by this module</b><br>')\" onmouseout=\"UnTip()\"><b>Method</b></th>
				    <th width=\"230\" align=\"center\" valign=\"middle\" onmouseover=\"Tip('Select proper background set for each of the selected modules.<br><br>Background set can be either <b>another query result specified above</b> <br><br>or <b>full HUGO Gene set, PubMed, or all the targets from users&quot; queries</b>')\" onmouseout=\"UnTip()\"><b>Test against</b></th>
				    <th width=\"150\" align=\"center\"><b>Note</b></th>
				</tr>
				<tr>
				    <td align=\"center\" valign=\"middle\">
				        <input type=\"checkbox\" name=\"GeneEnrichmentCheck\">
				    </td>
				    <td align=\"left\" valign=\"middle\" onmouseover=\"Tip('This module will evaluate significance level of <b>each target</b> from <b>test set</b><br>based on the <b>number of papers</b> per target <b>between test and background set</b><br><br><b>This module requires background set to be specified above.</b>')\" onmouseout=\"UnTip()\">
				        &nbsp;Gene (Name) Enrichment
				    </td>
				    <td align=\"center\" valign=\"middle\">
				        Fisher's exact
				    </td>
				    <td align=\"center\" valign=\"middle\">
				    	<select name=\"GeneEnrichment\" size=\"1\">
				            <option selected value=\"Selected\">Selected Background Above</option>
				            <!--
				            <option value=\"Whole\">Whole document in SciMinerDB</option>
				            -->
						</select>
					</td>
				    <td width=\"150\" align=\"center\" valign=\"middle\">&nbsp;</td>
				</tr>
				<tr>
				    <td align=\"center\" valign=\"middle\">
				        <input type=\"checkbox\" name=\"GOEnrichmentCheck\">
				    </td>
				    <td align=\"left\" valign=\"middle\" onmouseover=\"Tip('This module will evaluate significance level of <b>Gene Ontology terms</b> <br>based on the <b>number of targets</b> per Gene Ontology <b>from test and background set</b><br><br>Note that Gene Ontology information is obtained from external annotation resources<br>like NCBI Entrez Gene database not from the text. No text-mining is involved here.<br><br>Background set can be either <b>specified query</b> above or <b>whole HUGO gene set</b>.')\" onmouseout=\"UnTip()\">
				        &nbsp;Gene Ontology (GO)&nbsp;Enrichment
				    </td>
				    <td align=\"center\" valign=\"middle\">
				        Fisher's exact
				    </td>
				    <td align=\"center\" valign=\"middle\">
				    	<select name=\"GOEnrichment\" size=\"1\">
				            <option selected value=\"Selected\">Selected Background Above</option>
				            <!--<option value=\"Whole\">Whole document in SciMinerDB</option>-->
				            <option value=\"FullHUGO\">All HUGO Genes in SciMinerDB</option>                    
						</select>
					</td>
				    <td align=\"center\" valign=\"middle\">&nbsp;</td>
				</tr>
				<tr>
				    <td align=\"center\" valign=\"middle\">
				        <input type=\"checkbox\" name=\"MeSHEnrichmentCheck\">
				    </td>
				    <td align=\"left\" valign=\"middle\" onmouseover=\"Tip('This module will evaluate significance level of <b>MeSH terms</b> <br>based on the <b>number of papers</b> per MeSH Term <b>from test set and background set</b><br><br>No text-mining is involved here. <br><br>Background set can be either <b>specified query</b> above or <b>whole MedLine documents</b>.')\" onmouseout=\"UnTip()\">
				        MeSH Term&nbsp;Enrichment
				    </td>
				    <td align=\"center\" valign=\"middle\">
				        Fisher's exact
				    </td>
				    <td align=\"center\" valign=\"middle\">
				    	<select name=\"MeSHEnrichment\" size=\"1\">
				            <option selected value=\"Selected\">Selected Background Above</option>
				            <!--<option value=\"Whole\">Whole document in SciMinerDB</option>-->
				            <option value=\"FullMeSH\">Whole document in PubMed DB</option>
						</select></td>
				    <td align=\"center\" valign=\"middle\">&nbsp;</td>
				</tr>
				<tr>
				    <td align=\"center\" valign=\"middle\">
				        <input type=\"checkbox\" name=\"PathwayEnrichmentCheck\">
				    </td>
				    <td align=\"left\" valign=\"middle\" onmouseover=\"Tip('This module will evaluate significance level of <b>pathway</b> <br>based on the <b>number of targets</b> per pathway <b>from test and background set</b><br><br>Note that pathway information is obtained from KEGG and Reactome per target<br> not from the text. No text-mining is involved here.<br><br>Background set can be either <b>specified query</b> above or <b>whole HUGO gene set</b>.')\" onmouseout=\"UnTip()\">
				    	Pathway Enrichment
				    </td>
				    <td align=\"center\" valign=\"middle\">
				        Fisher's exact
				    </td>
				    <td align=\"center\" valign=\"middle\">
				    	<select name=\"PathwayEnrichment\" size=\"1\">
				            <option selected value=\"Selected\">Selected Background Above</option>
				            <!--<option value=\"Whole\">Whole document in SciMinerDB</option>-->
				            <option value=\"FullHUGO\">All HUGO Genes in SciMinerDB</option>  
						</select></td>
				    <td align=\"center\" valign=\"middle\">
				    	&nbsp;
				    </td>
				</tr>
				<tr>
				    <td align=\"center\" valign=\"middle\">
				        <input type=\"checkbox\" name=\"PPICheck\">
				    </td>
				    <td align=\"left\" valign=\"middle\" onmouseover=\"Tip('This module will evaluate significance of <b>PPI network</b> of the tested set.<br>The PPI network of the selected tested set is compared to <br>PPI networks of randomly selected targets (<b>of same number of targets as in the test set</b>).<br><br>Background set will provide the probabily of targets being randomly selected.<br>1) <b>Selected query above</b>: # of paper per target only in the given query<br>2) <b>All HUGO genes in SciMinerDB</b>: each gene is equally likely to be selected from the full HUGO gene list<br>3) <b>whole document in sciMinerDB</b>: # of paper per target from all of the processed documents<br><br>Note that 3) would change as more queries are used. <br>Though this is biased towards SciMiner users interests, <br>this can still be useful when the frequency of target needs to be incorporated into the selection probability. <br><br>PPI data is obtained from the MiMI (Michigan Molecular Interactions) database.')\" onmouseout=\"UnTip()\">
				        Protein-Protein Interaction network of targets
				    </td>
				    <td align=\"center\" valign=\"middle\">T-test, Z-score<br>
		 (100 repetitions)</td>
				    <td align=\"center\" valign=\"middle\" onmouseover=\"Tip('Background set will provide the probabily of targets being randomly selected.<br>1) <b>Selected query above</b>: # of paper per target only in the given query<br>2) <b>All HUGO genes in SciMinerDB</b>: each gene is equally likely to be selected from the full HUGO gene list<br>3) <b>whole document in sciMinerDB</b>: # of paper per target from all of the processed documents<br><br>')\" onmouseout=\"UnTip()\">
				    	<select name=\"PPI\" size=\"1\">
				            <option value=\"FullHUGO\" selected>All HUGO Genes in SciMinerDB</option>
				            <option value=\"Whole\">Whole document in SciMinerDB</option>
				            <option value=\"Selected\">Selected Background Above</option>
						</select>
					</td>
				    <td align=\"center\" valign=\"middle\">Based on Gauchian distribution</td>
				</tr>
			</table>
		

    <p>&nbsp;</p>
    <p><input type='submit' name=\"Start Analysis\" value=\"Start Analysis\"> <input type=\"reset\" name=\"reset form\"></p>
</form>";

}


sub print_end_html
{   print_footer();
    print end_html;
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


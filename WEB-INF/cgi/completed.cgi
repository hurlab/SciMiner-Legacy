#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                FuncAnal.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         sciminer @ umich . edu
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
function ncbi_preview_window()
{	var url	= 'https://pubmed.ncbi.nlm.nih.gov/?term=';
	var name = 'PubMed_Preview';
	var queryString = document.getElementsByName("queryString")[0].value;
	url = url + queryString;
	if (queryString.length > 0 )
	{   window.open(url, name);
	}else
	{   // do nothing.
	}
	
}   // ncbi_preview_window()

function showhide(id, id2){
    if (document.getElementById){
        obj = document.getElementById(id);
        obj2 = document.getElementById(id2);
        if (obj.style.display == "none"){
            obj.style.display = "inline";
            obj2.innerHTML = "Show less options.";
        } else {
            obj.style.display = "none";
            obj2.innerHTML = "Show more options.";
        }
    }
}

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

function delete_analysis(analysisID){
	var retval = window.confirm(' Are you sure to permanently delete this analysis ID ' + analysisID + ' result ?');
	if (retval)
	{   document.getElementsByName('DeleteQuery')[0].value 		= '';
		document.getElementsByName('DeleteAnalysis')[0].value 	= 'delete';
		document.getElementsByName('DeleteID')[0].value 		= analysisID;
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
#my @tmpSplit1 = split(/\/\//, $my_url);
#my @tmpSplit2 = split(/\//, $tmpSplit1[1]);
#my $tmpLocalURL = "http://$tmpSplit2[0]";


#------------------------------------------------------------------------------
#  Create temporary directory fild handling and give writable permission
#------------------------------------------------------------------------------
#my $upload_dir = "/tmp/SciMiner/";
#mkdir ($upload_dir) || print "";
#`chmod 777 $upload_dir` || print "";


#------------------------------------------------------------------------------
#  Initialize varialbes
#------------------------------------------------------------------------------
my $CurrentDate = `date`;
#my $currentNewDate = getdate();



#------------------------------------------------------------------------------
#  Initialize the CGI page
#------------------------------------------------------------------------------
print header;
print $query->start_html(-title=>'SciMiner Completed Query/Analysis Results', 
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

#my $passCode                    = param("passCode");
my $keyword						= param("keyword");

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
    print_end_html();
    exit;


}elsif ((defined param("DeleteAnalysis")) && (param("DeleteAnalysis") eq 'delete'))
{	print_FuncAnal_Header();
    print_section1_form();
    
    if ((defined param('DeleteID')) && (param('DeleteID') ne ""))
	{	delete_analysis(param('DeleteID'));
	}
	
    print_analysis_list_selection_from_SciMinerDB($email, $keyword);
    print_end_html();
    exit;


}elsif (defined param("RetrieveCompletedQuery"))
{   print_FuncAnal_Header();
    print_section1_form();

    print_query_list_selection_from_SciMinerDB($email, $keyword);
    print_end_html();
    exit;
    
}elsif (defined param("RetrieveCompletedAnalysis"))
{   print_FuncAnal_Header();
    print_section1_form();
    
    print_analysis_list_selection_from_SciMinerDB($email, $keyword);
    print_end_html();
    exit;
    
}
else
{   #  No button is clicked. Print out default forms
    print_FuncAnal_Header();
    print_section1_form();
    print_end_html();
    exit;
}






























#  -------------------------------------------------------------------------------------------------------



sub print_FuncAnal_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>SciMiner Completed Query/Analysis Results</U></b></p>
           ";

}

sub print_section1_form
{   print "<form name=\"form2\" action=\"completed.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
				<p class=\"titleBarName1\">(<b>Section_1</b>) Search your SciMiner mining results by<br>
			
			&nbsp;&nbsp;Query name : <INPUT TYPE='text' NAME='keyword' size=\"30\" onmouseover=\"Tip('Limit your search by partial query name')\" onmouseout=\"UnTip()\"> &nbsp;&nbsp;&nbsp;&nbsp;
			<br><br>
		    <INPUT TYPE=\"HIDDEN\" NAME=\"email\" VALUE=\"".$email."\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteQuery\" VALUE=\"\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteAnalysis\" VALUE=\"\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteID\" VALUE=\"\">
		    
			  <input type='submit' name=\"RetrieveCompletedQuery\" value=\"Retrieve Completed Query\" onmouseover=\"Tip('Click to retrieve completed SciMiner search queries')\" onmouseout=\"UnTip()\"> 
			  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			  <input type='submit' name=\"RetrieveCompletedAnalysis\" value=\"Retrieve Completed Analysis\" onmouseover=\"Tip('Click to retrieve completed post-mining analyses')\" onmouseout=\"UnTip()\"> 
			  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			  <INPUT TYPE=\"RESET\">
			  </p>
			</form>
			";

}

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
    <p>&nbsp;</p>
    ";
    
    print $outputHTML;
    return (\%queryID2BaseName);
}







sub print_analysis_list_selection_from_SciMinerDB
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
    	return();
    }
    
    
    #  Prefetch query result URLs
    my %queryID2resultURL	= ();
    my %queryID2displayStr	= ();
    $sql					= "SELECT queryID, queryName, numPMID, numGene, resultURL FROM query where status = 3 and userID = (SELECT userID FROM user WHERE email = \"$email\") ORDER BY queryID";
    $sth					= $dbh->prepare($sql);
    $sth->execute();
    @row         			= ();
    while(@row = $sth->fetchrow_array)
    {   if (defined $row[4])
    	{   $queryID2resultURL{$row[0]}		= $row[4];
    		$queryID2displayStr{$row[0]}	= $row[0]." (\'$row[1]\', \'$row[2]\', \'$row[3]\')";
    	}
    }
    
    #  Retreive Analysis results
    $sql         = "SELECT analID, TQueryID, BGQueryID, dateCreate, analURL, gene, go, mesh, pathway, ppi FROM analysis WHERE status = 3 and deleted = 0 and userID = (SELECT userID FROM user WHERE email = \"$email\" ) ORDER BY analID";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
    @row         = ();
    
    my $outputHTML  = "<p class=\"titleBarName1\">(<b>Section_2</b>) Here are the list of your previous SciMiner anlaysis results. (completed only)<br>
                        </p>
                        
                        <table border=\"1\" width=\"870\">
                            <tr class=\"tableHeader1\">
                                <th width=\"60\" onmouseover=\"Tip('<b>Analysis Number</b>: A unique ID for each analysis')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Analysis<br>Number</b></p>
                                </th>
                                <th width=\"280\" onmouseover=\"Tip('<b>Target Query</b>: This is the query result that was used as the <b>TEST</b> set in post-mining analysis')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Target Query</b><br>
                                    QueryID (Name, #PMIDs, #Targets)</p>
                                </th>
                                <th width=\"280\" onmouseover=\"Tip('<b>Background Query</b>: This is the query result that was used as the <b>BACKGROUND</b> set in post-mining analysis')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Background Query</b><br>
                                    QueryID (Name, #PMIDs, #Targets)</p>
                                </th>
                                <th width=\"90\" onmouseover=\"Tip('<b>Date</b>: The data on which the analysis was submitted')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Date</b></p>
                                </th>
                                <th width=\"100\" onmouseover=\"Tip('<b>Tests</b>: Types of post-mining analyses done here<br><img src=&quot;/SciMiner1.1/SciMiner/Images/G.jpg&quot;>: Gene (Target) list<br><img src=&quot;/SciMiner1.1/SciMiner/Images/O.jpg&quot;>: Gene Ontology<br><img src=&quot;/SciMiner1.1/SciMiner/Images/M.jpg&quot;>: MeSH Term<br><img src=&quot;/SciMiner1.1/SciMiner/Images/P.jpg&quot;>: Pathways<br><img src=&quot;/SciMiner1.1/SciMiner/Images/I.jpg&quot;>: Protein-Protein Interactions<br>')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Tests</b></p>
                                </th>
                                <th width=\"40\" onmouseover=\"Tip('<b>Link</b>: The Post-Mining Analysis result page')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Link</b></p>
                                </th>
                                <th width=\"30\" onmouseover=\"Tip('<b>Del</b>: Delete the analysis')\" onmouseout=\"UnTip()\">
                                    <p align=\"center\"><b>Del</b></p>
                                </th>
                            </tr>";
    
    while(@row = $sth->fetchrow_array)
    {   $outputHTML 	.=  "<tr>
                            	<td>&nbsp;$row[0]</td>
                            	<td>&nbsp;<a href=\"$queryID2resultURL{$row[1]}\">$queryID2displayStr{$row[1]}</a></td>";
        if ((defined $row[2]) && ($row[2] ne ""))
        {	$outputHTML	.=	"<td>&nbsp;<a href=\"$queryID2resultURL{$row[2]}\">$queryID2displayStr{$row[2]}</a></td>";
        }else
        {	$outputHTML	.=	"<td>&nbsp;</td>";
        }

		#  Date
		$outputHTML	.=	"<td>&nbsp;$row[3]</td>";

		#  Tests
		$outputHTML .= "<td>";
		if ((defined $row[5]) && ($row[5] == 1))
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/G.jpg\" onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/G.jpg&quot;>: Gene (Target) list')\" onmouseout=\"UnTip()\">";
		}else
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/BLANK.jpg\">";
		}
		if ((defined $row[6]) && ($row[6] == 1))
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/O.jpg\" onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/O.jpg&quot;>: Gene Ontology')\" onmouseout=\"UnTip()\">";
		}else
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/BLANK.jpg\">";
		}
		if ((defined $row[7]) && ($row[7] == 1))
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/M.jpg\" onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/M.jpg&quot;>: MeSH Term')\" onmouseout=\"UnTip()\">";
		}else
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/BLANK.jpg\">";
		}
		if ((defined $row[8]) && ($row[8] == 1))
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/P.jpg\" onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/P.jpg&quot;>: Pathway')\" onmouseout=\"UnTip()\">";
		}else
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/BLANK.jpg\">";
		}
		if ((defined $row[9]) && ($row[9] == 1))
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/I.jpg\" onmouseover=\"Tip('<img src=&quot;/SciMiner1.1/SciMiner/Images/I.jpg&quot;>: Protein-Protein Interactions')\" onmouseout=\"UnTip()\">";
		}else
		{	$outputHTML	.= "<img src=\"/SciMiner1.1/SciMiner/Images/BLANK.jpg\">";
		}						
		$outputHTML .= "</td>";
		
		# Links and Del
		if ((defined $row[4]) && ($row[4] ne ""))
		{	$outputHTML	.= "<td>&nbsp;<a href=\"/SciMiner1.1/$row[4]\" onmouseover=\"Tip('Click here to see analysis ID #$row[0] result')\" onmouseout=\"UnTip()\"><img src=\"/SciMiner1.1/SciMiner/Images/R.jpg\"></a></td>";
		}else
		{	$outputHTML	.= "<td>&nbsp;</td>";
		}
		
		# Delete button
    	$outputHTML .= "<td>&nbsp;<a href=\"#\" onclick=\"delete_analysis($row[0])\" onmouseover=\"Tip('Click here to delete query ID #$row[0] result')\" onmouseout=\"UnTip()\"><img src=\"/SciMiner1.1/SciMiner/Images/D.jpg\"></a></td>";
    	
    	$outputHTML .= '</tr>';

    }
    
    
    $outputHTML .= '</table>
     <p>&nbsp;</p>';
    print $outputHTML;
}







sub print_end_html
{   print "<p class=\"tableHeader1\">Place the mouse pointer to get a quick tip!</a>";

	print_footer();
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


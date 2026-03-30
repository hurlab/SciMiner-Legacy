#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                editSciMinerFinding.cgi for SciMiner on the web
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
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");
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
                        -style=>{-src=>['/SciMiner1.1/css/sciminer-modern.css'], -code=>$newStyle},
                        -onLoad=>'closeW()'
                        );

print "<script type='text/javascript' src='wz_tooltip.js'></script>";                       
print_SciMiner_Header();


#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------
my $sen2geneID			= param("sen2geneID");
my $fileNameBase		= param("fileNameBase");
my $matchString			= param("matchString");
my $oldHUGOID			= param("oldHUGOID");
my $actualString		= param("actualString");

my $scope				= param("scope");
my $newHugoID			= param("newHugoID");
my $pmid				= '';
my $userID				= '';
my $editLevel			= '';

my $hgncLinkURL         = "https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/";
my $ncbiGeneSearch		= "https://www.ncbi.nlm.nih.gov/gene/?term=";
my $ncbiGeneURL			= "https://www.ncbi.nlm.nih.gov/gene/";
my @errorMessage		= ();

#------------------------------------------------------------------------------
#	Load Summary List
#------------------------------------------------------------------------------
my $finalResultURL		= '';
my $finalStatus			= 'local';



#------------------------------------------------------------------------------
#	Get user edit level
#------------------------------------------------------------------------------
($editLevel, $userID)	= get_user_editlevel ($fileNameBase, \%annoENV);


#------------------------------------------------------------------------------
#	Retrieve PMID for the selected $sen2geneID
#------------------------------------------------------------------------------
$pmid					= retrieve_PMID_for_give_sen2geneID($sen2geneID, \%annoENV);





#------------------------------------------------------------------------------
#	Check the transferred content
#------------------------------------------------------------------------------
if ((defined param("PerformUpdateDelete")) && (param("PerformUpdateDelete") eq 'yes'))
{	if ( ((defined $sen2geneID) && ($sen2geneID ne "")) &&
		 ((defined $fileNameBase) && ($fileNameBase ne "")) &&
		 ((defined $matchString) && ($matchString ne "")) &&
		 ((defined $oldHUGOID) && ($oldHUGOID ne "")) &&
		 ((defined $editLevel) && ($editLevel ne ""))
	   )
	{	if ((defined param("UpdateRecord")) && (param("UpdateRecord") eq 'update'))
		{	my ($updateStatus, $updateCount, $message) = update_by_matchString_actualString_scope($sen2geneID, $fileNameBase, $matchString, 
					$actualString, $oldHUGOID, $newHugoID, param("editScope"), \%annoENV, $editLevel, $userID, $pmid);
			if ($updateStatus ==0)
			{	push @errorMessage, "updateStatus : failed";
				push @errorMessage, "updateMessage: $message";
			}else
			{	print "! Updating records was successful. <br> $updateCount records have been updated.<br><br>\n";
				print "<b> You MUST click 'Regenerate the result HTML at the bottom of the main result summary page</b><br><br>or, re-submit the SciMiner query but DO NOT REFRESH HERE.<br><br>\n";
				print "<b> This page will be closed in 10 seconds </b><br>";
				print "<INPUT TYPE=\"HIDDEN\" NAME=\"PROCESSED\" VALUE=\"YES\">";
				print_end_html();
				exit;
			}
		}elsif ((defined param("DeleteRecord")) && (param("DeleteRecord") eq 'delete'))
		{	my ($deleteStatus, $deleteCount) = delete_by_matchString_actualString_scope($sen2geneID, $fileNameBase, $matchString, 
					$actualString, $oldHUGOID, param("editScope"), \%annoENV, $editLevel, $userID, $pmid);
			if ($deleteStatus ==0)
			{	push @errorMessage, "deleteStatus : failed";
			}else
			{	print "! Deleting records was successful. <br> $deleteCount records have been deleted.<br><br>\n";
				print "<b> You MUST click 'Regenerate the result HTML at the bottom of the main result summary page</b><br><br>or, re-submit the SciMiner query but DO NOT REFRESH HERE.<br><br>\n";
				print "<b> This page will be closed in 10 seconds </b><br>";
				print "<INPUT TYPE=\"HIDDEN\" NAME=\"PROCESSED\" VALUE=\"YES\">";
				print_end_html();
				exit;
			}
		}else
		{	# show any conflict
			print_conflict_information();
			print_option_form();
			print_end_html();
			exit;
		}
	}else
	{	push @errorMessage, "Required parameters are missing";
		push @errorMessage, "sen2geneID: $sen2geneID";
		push @errorMessage, "fileNameBase: $fileNameBase";
		push @errorMessage, "matchString: $matchString";
		push @errorMessage, "actualString: $actualString";
		push @errorMessage, "oldHUGOID: $oldHUGOID";
		push @errorMessage, "editLevel: $editLevel";
		push @errorMessage, "userID: $userID";
	}   
}else
{	# show any conflict
	print_conflict_information();
	print_option_form();
	print_end_html();
	exit;
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





#------------------------------------------------------------------------------
#	Sub-routines
#------------------------------------------------------------------------------
sub get_user_editlevel
{	my $fileNameBase	= shift;
	my $annoENVRef		= shift;
	
	
	#  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

	#  Read the configuration file
	if (-f $$annoENVRef{"SciMinerWebPath"}."FinalResults/$fileNameBase/$fileNameBase.conf")
	{	open (CONF, $$annoENVRef{"SciMinerWebPath"}."FinalResults/$fileNameBase/$fileNameBase.conf");
		my $email			= '';
		while(<CONF>)
		{	my $line = $_;
			$line =~ s/\r|\n//g;
			my @tmpSplit 	= split (/\t/, $line);
			if ($tmpSplit[0] eq 'email')
			{	$email	= $tmpSplit[1];
				last;
			}
		}
		close CONF;
		
		if ((not defined $email) || ($email eq ""))
		{	return(0,0);
		}

		#  Retrieve edit level
		my $sql         = "SELECT editLevel, userID FROM user where email like '$email'";
		my $sth         = $dbh->prepare($sql);
		$sth->execute();
		my @row         = $sth->fetchrow_array;
		
		if ((defined $row[1]) && ($row[1] ne ""))
		{	return($row[0], $row[1]);
		}
	}else
	{	return(0,0);
	}
}




sub retrieve_PMID_for_give_sen2geneID
{	my $sen2geneID		= shift;
	my $annoENVRef		= shift;
	
	
	#  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);
	my $sql         = "SELECT pmid FROM sentence2gene WHERE sen2geneID = $sen2geneID";
	my $sth         = $dbh->prepare($sql);
	$sth->execute();
	my @row         = $sth->fetchrow_array;
	
	if (defined $row[0])
	{	return($row[0]);
	}else
	{	return("");
	}
}



sub retrieve_conflict_information
{	my $matchString			= shift;
	my $annoENVRef				= shift;
	
	#  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);


	#  check the length 
    #  Check duplicate symbol and duplicate name                     
    my $sql         = "SELECT duplicateSymbol, hgncID FROM duplicatesymbol";
    my $sth         = $dbh->prepare($sql);
    $sth->execute();
    my @row         = ();
    my %dup			= ();
    
    while(@row=$sth->fetchrow_array)
    {	$row[0]		= lc($row[0]);
    	if (defined $dup{$row[0]})
    	{	push @{$dup{$row[0]}}, $row[1];
    	}else
    	{	$dup{$row[0]}->[0]	= $row[1];
    	}
    }
    
    
    $sql         = "SELECT duplicateName, hgncID FROM duplicatename";
    $sth         = $dbh->prepare($sql);
    $sth->execute();
    @row         = $sth->fetchrow_array;
    
    while(@row=$sth->fetchrow_array)
    {	$row[0]		= lc($row[0]);
    	if (defined $dup{$row[0]})
    	{	push @{$dup{$row[0]}}, $row[1];
    	}else
    	{	$dup{$row[0]}->[0]	= $row[1];
    	}
    }
    
	
	#  Check for duplicate symbol 
	my %hgncID2approvedSymbol	= ();
	my %hgncID2approvedName		= ();
	my %hgncID2NCBIEntrezID		= ();
	my %hgncID2geneID			= ();
      
	
	if (defined $dup{lc($matchString)})
	{	#  Retrieve Gene Information
		my $hgncIDStr	= join(",", @{$dup{lc($matchString)}});
		$sql         	= "SELECT hgncID, approvedSymbol, approvedName, geneID, entrezGeneIDMappedData FROM gene WHERE hgncID in ($hgncIDStr)";
		$sth         	= $dbh->prepare($sql);
		$sth->execute();
		while(@row=$sth->fetchrow_array)
		{	if (defined $row[4])
			{	$hgncID2approvedSymbol{$row[0]}	= $row[1];
				$hgncID2approvedName{$row[0]}	= $row[2];
				$hgncID2geneID{$row[0]}			= $row[3];
				$hgncID2NCBIEntrezID{$row[0]}	= $row[4];
			}else
			{	$hgncID2approvedSymbol{$row[0]}	= $row[1];
				$hgncID2approvedName{$row[0]}	= $row[2];
				$hgncID2geneID{$row[0]}			= $row[3];
				#$hgncID2NCBIEntrezID{$row[0]}	= "";
			}
		}
	}
	    
    return(\%hgncID2approvedSymbol, \%hgncID2approvedName, \%hgncID2NCBIEntrezID, \%hgncID2geneID, \%dup);
}



sub print_conflict_information
{	my ($hgncID2approvedSymbolRef, $hgncID2approvedNameRef, $hgncID2NCBIEntrezIDRef, $hgncID2geneIDRef, $dupStringHashRef) = retrieve_conflict_information($matchString, \%annoENV);
	if (defined $$dupStringHashRef{lc($matchString)})
	{	print "<p class=\"titleBarName1\">Here is the list of conflict information for the match string <b>'$matchString'</b> in SciMiner dictionaries. It does not always mean that these are all of the possible conflicts for this <b>'$matchString'</b> at all. There could be other conflicts that have not been captured by SciMiner.</p>
			<table border=\"1\" width=\"800\">
			<tr class=\"tableHeader1\">
				<th width=\"100\">
				    HUGOID
				</th>
				<th width=\"100\">
				    ApprovedSymbol
				</th>
				<th width=\"500\">
				    ApprovedName
				</th>
				<th width=\"100\">
				    EntrezGeneID
				</th>
			</tr>
			";

		foreach my $tmpHugoID (@{$$dupStringHashRef{lc($matchString)}})
		{	print "<tr><td><a href=\"$hgncLinkURL$tmpHugoID\">$tmpHugoID</a></td><td>$$hgncID2approvedSymbolRef{$tmpHugoID}</td><td>$$hgncID2approvedNameRef{$tmpHugoID}</td>";
			if (defined $$hgncID2NCBIEntrezIDRef{$tmpHugoID})
			{	print "<td><a href=\"$ncbiGeneSearch$$hgncID2NCBIEntrezIDRef{$tmpHugoID}\">$$hgncID2NCBIEntrezIDRef{$tmpHugoID}</a></td></tr>\n";
			}else
			{	print "<td>&nbsp;</td></tr>\n";
			}	
		}
		print " </table><p class=\"titleBarName1\"><br><b><u>Current Entry</u></b><br>You have envoked this script for the following identification result. Note that <b>Match String</b> is the form in SciMiner dictionary, while <b>Actual String</b> is the actual form found in the document. <b>Actual String</b> has more variable forms.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;PMID: $pmid &nbsp;&nbsp;&nbsp; HUGO ID: <a href=\"$hgncLinkURL$oldHUGOID\">$oldHUGOID</a> &nbsp;&nbsp;&nbsp; Match String: <b>$matchString</b> &nbsp;&nbsp;&nbsp; Actual String: <b>$actualString</b><br><br></p>\n";
	}else
	{	#  There is no conflict information available
		print "<p class=\"titleBarName1\">No conflict symbol/name information for the current entry has been found in SciMiner dictionary. It does not always mean that there is no conflict for this <b>'$matchString'</b> at all. There could be some conflicts that have not been captured by SciMiner.</p>";
		print "<p class=\"titleBarName1\"><br><b><u>Current Entry</u></b><br>You have envoked this script for the following identification result. Note that <b>Match String</b> is the form in SciMiner dictionary, while <b>Actual String</b> is the actual form found in the document. <b>Actual String</b> has more variable forms.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;PMID: $pmid &nbsp;&nbsp;&nbsp; HUGO ID: <a href=\"$hgncLinkURL$oldHUGOID\">$oldHUGOID</a> &nbsp;&nbsp;&nbsp; Match String: <b>$matchString</b> &nbsp;&nbsp;&nbsp; Actual String: <b>$actualString</b><br><br></p>\n";
	}
}



sub print_option_form
{	print "	<form name=\"form1\" action=\"editSciMinerFinding.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
			<INPUT TYPE=\"HIDDEN\" NAME=\"sen2geneID\" VALUE=\"$sen2geneID\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"fileNameBase\" VALUE=\"$fileNameBase\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"matchString\" VALUE=\"$matchString\">
		    <INPUT TYPE=\"HIDDEN\" NAME=\"actualString\" VALUE=\"$actualString\">		    
		    <INPUT TYPE=\"HIDDEN\" NAME=\"oldHUGOID\" VALUE=\"$oldHUGOID\">	
		    <INPUT TYPE=\"HIDDEN\" NAME=\"PerformUpdateDelete\" VALUE=\"\">	
		    <INPUT TYPE=\"HIDDEN\" NAME=\"UpdateRecord\" VALUE=\"\">	
		    <INPUT TYPE=\"HIDDEN\" NAME=\"DeleteRecord\" VALUE=\"\">	
		    
		    <p align=\"center\" class=\"pageName\"><b><U>Modification Scope</U></b></p>
			<p class=\"sectionTitleBar1\" align=\"center\"><font size=\"5\" color=\"RED\">! MAKE SURE THAT YOU COMPLETELY UNDERSTAND WHAT YOU ARE DOING HERE !<br>
			! CHECK THE IDENTIFICATION RESULTS THOROUGHLY !<br>
			! USE <u>HUGO ID</u> FOR NEW ASSIGNMENT !</font></b><p>

			<p class=\"titleBarName1\"><b>If you are sure what you are going to do, select your modification option.</b></p>			
			<select name=\"editScope\" size=\"1\" onmouseover=\"Tip('* <b><u>This specific finding</u></b>: Change is only applied to this identification.<br><br>* <b><u>Within this document</u></b>: Change is only applied to the document for any identification <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;with the exactly same <b>HUGO ID</b>, <b>Match String></b>, and <b>Actual String</b>.<br><br>* <b><u>Within this document - All by the matchString</u></b>: Change is applied to only to the <b>current document (PMID)</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;for any identification has the exactly same <b>HUGO ID</b> and <b>Match String</b>.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>(Actual String is <b>NOT</b> checked.)</b><br><br>* <b><u>Within the query corpus</u></b>: Change is applied to every document in the <b>query</b> for any identification <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;with the exactly same <b>HUGO ID</b>, <b>Match String</b>, and <b>Actual String</b>.<br><br>* <b><u>Within the query corpus - All by the matchString</u></b>: Change is applied to <b>every document</b> in the <b>query</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;for any identification has the exactly same <b>HUGO ID</b> and <b>Match String</b>.<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>(Actual String is <b>NOT</b> checked.)</b><br>')\" onmouseout=\"UnTip()\">
				        <option selected value=\"single\">This specific finding</option>
				        <option value=\"single\">This specific finding</option>
				        <option value=\"document\">Within this document</option>
				        <option value=\"matchStringDoc\">Within this document - All by the matchString</option>
						<option value=\"corpus\">Within the query corpus</option>
				        <option value=\"matchString\">Within the query corpus - All by the matchString</option>
			</select>
			
			
			<br><br>
			<a href=\"javascript:ncbi_preview_window();\" onmouseover=\"Tip('Click here to search <b>$matchString</b> against the NCBI Entrez gene database.')\" onmouseout=\"UnTip()\">Search NCBI Entrez Gene and find a relevant HUGO ID (HGNC ID)</a><br>
			<p class=\"titleBarName1\">Enter new HUGO ID&nbsp;&nbsp;<input type=\"text\" name=\"newHugoID\" size=\"4\" value=\"\" style=\"text-align: right\">&nbsp;&nbsp;</p>
			<a href=\"#\" onclick=\"confirm_update()\" onmouseover=\"Tip('Click here to <b>UPDATE</b> SciMiner identification results to the new ID above.')\" onmouseout=\"UnTip()\"><img src=\"/SciMiner1.1/SciMiner/Images/UPDATE.jpg\"></a>
			<a href=\"#\" onclick=\"confirm_delete()\" onmouseover=\"Tip('Click here to <b>DELETE</b> SciMiner identification results according to the selection option.')\" onmouseout=\"UnTip()\"><img src=\"/SciMiner1.1/SciMiner/Images/DELETE.jpg\"></a>
			</form>
			";
			
#			<option value=\"whole\">Everything in the SciMinerDB (This requires special user level.)</option>

#			<select name=\"editScope\" size=\"1\" onmouseover=\"Tip('* <b>This specific finding</b>: Change is only applied to this identification.<br><br>* <b>Within this document</b>: Change is only applied to the document for any identification <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;with the exactly same <b>HUGO ID</b>, <b>Match String></b>, and <b>Actual String</b>.<br><br>* <b>Within the query corpus</b>: Change is applied to every document in the <b>query</b> for any identification <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;with the exactly same <b>HUGO ID</b>, <b>Match String</b>, and <b>Actual String</b>.<br><br>* <b>Within the query corpus - All by the matchString</b>: Change is applied to every document in the <b>query</b><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;for any identification has the exactly same <b>HUGO ID</b> and <b>Match String</b>. <b>(This is the most broad option)</b><br>')\" onmouseout=\"UnTip()\">
#				        <option selected value=\"single\">This specific finding</option>
#				        <option value=\"single\">This specific finding</option>
#				        <option value=\"document\">Within this document</option>
#				        <option value=\"corpus\">Within the query corpus</option>
#						<option value=\"matchString\">Within the query corpus - All by the matchString</option>
#			</select>
}












sub print_SciMiner_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>SciMiner Identification Editing</U></b></p>
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



sub update_by_matchString_actualString_scope
{	my $sen2geneID		= shift;
	my $fileNameBase	= shift;
	my $matchString		= shift;
	my $actualString	= shift;
	my $oldHUGOID		= shift;
	my $newHugoID		= shift;
	my $editScope		= shift;
	my $annoENVRef		= shift;
	my $editLevel		= shift;
	my $userID			= shift;
	my $pmid			= shift;
	
	my $updateStatus	= 0;
	my $updateCount		= 0;
	my $workingDir		= $$annoENVRef{"SciMinerWebPath"}."FinalResults/$fileNameBase/";


	#  Check if the new hugoID is number
	if (!is_number($newHugoID))
	{	return(0,0, "Entered $newHugoID is not in numeric form. Please check your hugoID");
	}
	
	
	#  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         		= DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      			return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);
	my $line				= '';
	my @tmpSplit			= ();
	my $sql					= '';
	my $sth					= '';
	my @row					= ();
	
	my $newGeneID			= 0;
	my $newApprovedSymbol	= '';
	
	#  ------------------------------------------------------------------------
    #  Get the geneID from hgncID
    #  ------------------------------------------------------------------------
    $sql			= "SELECT geneID, approvedSymbol FROM gene where hgncID = $newHugoID";
    $sth         	= $dbh->prepare($sql);
	$sth->execute();
    @row         	= $sth->fetchrow_array;
    
    if (defined $row[1])
    {	$newGeneID			= $row[0];
    	$newApprovedSymbol	= $row[1];
    }else
    {	return(0,0, "No geneID for the given HUGO ID $newHugoID. Please check your hugoID");
    }
    
	#  Check the scope
	if ($editScope 	eq 'single')
	{	#  Retrieve the corresponding information for the given sen2geneID
		$sql         = "SELECT * FROM sentence2gene WHERE sen2geneID = $sen2geneID";
		$sth         = $dbh->prepare($sql);
		$sth->execute();
		@row         = $sth->fetchrow_array;
		if (defined $row[0])
		{	my $tmpGeneID			= $row[3];
			my $tmpHugoID			= $row[4];
			my $tmpApprovedSymbol	= $row[5];
			my $tmpInExClude		= $row[15];
			my $tmpInExCludeCond	= $row[16];
			
			$dbh->do("UPDATE sentence2gene SET geneID = $newGeneID, hgncID = $newHugoID, approvedSymbol = \"$newApprovedSymbol\", editTag = 1, editUser = $userID, inExClude=1, inExCludeCond=\"UserEdit\", oldGeneID = $tmpGeneID, oldHgncID = $tmpHugoID, oldApprovedSymbol = \"$tmpApprovedSymbol\", oldInExClude=$tmpInExClude, oldInExCludeCond=\"$tmpInExCludeCond\" WHERE sen2geneID = $sen2geneID") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $sen2geneID");
			return(1,1, "Successful");
		}else
		{	return(0,0, "No corresponding sentence2gene content has been found. Contact the system administrator");
		}
	}elsif ($editScope 	eq 'corpus')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
				
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString) && ($tmpSplit[7] eq $actualString))
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET geneID = $newGeneID, hgncID = $newHugoID, approvedSymbol = \"$newApprovedSymbol\", editTag = 1, editUser = $userID, inExClude=1, inExCludeCond=\"UserEdit\", oldGeneID = $tmpSplit[3], oldHgncID = $tmpSplit[4], oldApprovedSymbol = \"$tmpSplit[5]\", oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$updateCount++;					
				}
			}
			close FILE;
			return(1, $updateCount);
		}else
		{	return(1, $updateCount);
		}
	}elsif ($editScope 	eq 'matchString')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
				
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString))  # && ($tmpSplit[7] eq $actualString))
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET geneID = $newGeneID, hgncID = $newHugoID, approvedSymbol = \"$newApprovedSymbol\", editTag = 1, editUser = $userID, inExClude=1, inExCludeCond=\"UserEdit\", oldGeneID = $tmpSplit[3], oldHgncID = $tmpSplit[4], oldApprovedSymbol = \"$tmpSplit[5]\", oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$updateCount++;					
				}
			}
			close FILE;
			return(1, $updateCount);
		}else
		{	return(1, $updateCount);
		}
	}elsif ($editScope eq 'document')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
				
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString) && ($tmpSplit[7] eq $actualString) && ($tmpSplit[1] eq $pmid))
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET geneID = $newGeneID, hgncID = $newHugoID, approvedSymbol = \"$newApprovedSymbol\", editTag = 1, editUser = $userID, inExClude=1, inExCludeCond=\"UserEdit\", oldGeneID = $tmpSplit[3], oldHgncID = $tmpSplit[4], oldApprovedSymbol = \"$tmpSplit[5]\", oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$updateCount++;					
				}
			}
			close FILE;
			return(1, $updateCount);
		}else
		{	return(1, $updateCount);
		}
	}elsif ($editScope eq 'matchStringDoc')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
				
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString) && ($tmpSplit[1] eq $pmid))	#&& ($tmpSplit[7] eq $actualString) 
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET geneID = $newGeneID, hgncID = $newHugoID, approvedSymbol = \"$newApprovedSymbol\", editTag = 1, editUser = $userID, inExClude=1, inExCludeCond=\"UserEdit\", oldGeneID = $tmpSplit[3], oldHgncID = $tmpSplit[4], oldApprovedSymbol = \"$tmpSplit[5]\", oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$updateCount++;					
				}
			}
			close FILE;
			return(1, $updateCount);
		}else
		{	return(1, $updateCount);
		}
	}elsif ($editScope eq 'whole')
	{	#	 This is to be created but it won't be easy to process all sentence2gene in the database
		return($updateStatus, $updateCount);
	}
}




sub delete_by_matchString_actualString_scope
{	my $sen2geneID		= shift;
	my $fileNameBase	= shift;
	my $matchString		= shift;
	my $actualString	= shift;
	my $oldHUGOID		= shift;
	my $editScope		= shift;
	my $annoENVRef		= shift;
	my $editLevel		= shift;
	my $userID			= shift;
	my $pmid			= shift;
	
	my $deleteStatus	= 0;
	my $deleteCount		= 0;
	my $workingDir		= $$annoENVRef{"SciMinerWebPath"}."FinalResults/$fileNameBase/";

	#  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);
	my $line			= '';
	my @tmpSplit		= ();
	my $sql				= '';
	my $sth				= '';
	my @row				= ();
	
	#  Check the scope
	if ($editScope 	eq 'single')
	{	#  Retrieve the corresponding information for the given sen2geneID
		$sql         = "SELECT * FROM sentence2gene WHERE sen2geneID = $sen2geneID";
		$sth         = $dbh->prepare($sql);
		$sth->execute();
		@row         = $sth->fetchrow_array;
		if (defined $row[0])
		{	my $tmpGeneID			= $row[3];
			my $tmpHugoID			= $row[4];
			my $tmpApprovedSymbol	= $row[5];
			my $tmpInExClude		= $row[15];
			my $tmpInExCludeCond	= $row[16];
			
			$dbh->do("UPDATE sentence2gene SET inExClude=2, inExCludeCond=\"UserEdit\", editTag = 1, editUser = $userID, oldInExClude=$tmpInExClude, oldInExCludeCond=\"$tmpInExCludeCond\" WHERE sen2geneID = $sen2geneID") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $sen2geneID");
			return(1,1);
		}else
		{	return(0,0);
		}
	}elsif ($editScope 	eq 'corpus')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
			
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString) && ($tmpSplit[7] eq $actualString))
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET inExClude=2, inExCludeCond=\"UserEdit\", editTag = 1, editUser = $userID, oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$deleteCount++;					
				}
			}
			close FILE;
			return(1, $deleteCount);
		}else
		{	return($deleteStatus, $deleteCount);
		}
	}elsif ($editScope 	eq 'matchString')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
			
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString)) # && ($tmpSplit[7] eq $actualString))
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET inExClude=2, inExCludeCond=\"UserEdit\", editTag = 1, editUser = $userID, oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$deleteCount++;					
				}
			}
			close FILE;
			return(1, $deleteCount);
		}else
		{	return($deleteStatus, $deleteCount);
		}
	}elsif ($editScope 	eq 'document')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
			
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString) && ($tmpSplit[7] eq $actualString) && ($tmpSplit[1] eq $pmid))
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET inExClude=2, inExCludeCond=\"UserEdit\", editTag = 1, editUser = $userID, oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$deleteCount++;					
				}
			}
			close FILE;
			return(1, $deleteCount);
		}else
		{	return($deleteStatus, $deleteCount);
		}
	}elsif ($editScope 	eq 'matchStringDoc')
	{	#  Check for the remaining file existence
		if (-f $workingDir."SciMinerBase.Both.Remain.txt")
		{	open (FILE, $workingDir."SciMinerBase.Both.Remain.txt");
			while(<FILE>)
			{	$line		= $_;
				$line		=~ s/\r|\n//g;
				@tmpSplit	= split(/\t/, $line);
			
				# Check for matching condition
				if (($tmpSplit[4] eq $oldHUGOID) && ($tmpSplit[6] eq $matchString) && ($tmpSplit[1] eq $pmid))	#($tmpSplit[7] eq $actualString) && 
				{	#  Update the contents
					$dbh->do("UPDATE sentence2gene SET inExClude=2, inExCludeCond=\"UserEdit\", editTag = 1, editUser = $userID, oldInExClude=$tmpSplit[15], oldInExCludeCond=\"$tmpSplit[16]\" WHERE sen2geneID = $tmpSplit[0]") || LogQuery("! ERROR: Cannot update the sentence2gene for sen2geneID $tmpSplit[0]");
					$deleteCount++;					
				}
			}
			close FILE;
			return(1, $deleteCount);
		}else
		{	return($deleteStatus, $deleteCount);
		}
	}elsif ($editScope eq 'whole')
	{	#	 This is to be created but it won't be easy to process all sentence2gene in the database
		return($deleteStatus, $deleteCount);
	}
}









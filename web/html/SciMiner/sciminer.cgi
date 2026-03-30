#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                GetQuery.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Last Modified : Nov 26, 2008
#  Desc:  This cgi accepts the start page for SciMiner on the web
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

function showhide(id, id2, message){
    if (document.getElementById){
        obj = document.getElementById(id);
        obj2 = document.getElementById(id2);
        if (obj.style.display == "none"){
            obj.style.display = "inline";
            obj2.innerHTML = "HIDE " + message + " !";
        } else {
            obj.style.display = "none";
            obj2.innerHTML = "SHOW " + message + " !";
        }
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
td {
	font:10px Arial, Helvetica, sans-serif;
	color:#666666;
	text-align:left;
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
print $query->start_html(-title=>'SciMiner CGI', 
                        -author=>'windysky.open@gmail.com',
                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
                        -script=> $JSCRIPT,
                        -BGCOLOR=>'#EAF4F4',
                        -style=>{-src=>['mm_health_nutr.css'],
                        		 -code=>$newStyle}
                        );

#print $query->start_html(-title=>'SciMiner CGI', 
#                        -author=>'windysky.open@gmail.com',
#                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
#                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
#                        -script=>{-language	=>	'javascript1.2',
#                        		  -src     	=>	'./sciminer.js'}
#                        -BGCOLOR=>'#EAF4F4');
print "<script type='text/javascript' src='wz_tooltip.js'></script>";                        
print_SciMiner_Header();

if (not defined param("submit form"))
{   print_form();
    print end_html;
    exit;
}

#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------
my $email                       = param("email");
my $userName                    = '';                  #param("userName");
my $maxNewDoc					= 0;
my $maxDoc						= 0;
my $userInstitute				= '';
#my $passCode                    = param("passCode");
my $queryName                   = param("queryName");
my $queryString                 = param("queryString");
my $listText                    = param("listText");
my $fileNameFull                = param("uploadFileName");
   $fileNameFull                =~ s/.*[\/\\](.*)/$1/;
my $uploadFileHandle            = upload("uploadFileName");
my $useLengthOption             = param("useLengthOption");
my $wordLengthThreshold         = param("wordLengthThreshold");
my $phenotypeOnlyFilter         = param("phenotypeOnlyFilter");
my $useScoreThreshold			= param("useScoreThreshold");
my $scoreThreshold				= param("scoreThreshold");

my $ignoreName                  = param("ignoreName");  
my $ignoreNameFile              = param("IgnoreListFile");
my $ignoreNameFileHandle        = '';
my $ignoreCustomText            = '';
if (($ignoreName) && ($ignoreNameFile ne ""))
{   $ignoreNameFileHandle   = upload("IgnoreListFile");
    $ignoreCustomText           = join ("", <$ignoreNameFileHandle>);
}
my $excludeSymbol               = param("excludeSymbol");  
my $excludeSymbolFile           = param("excludeSymbolFile");
my $excludeSymbolFileHandle     = '';
my $excludeCustomText           = '';
if (($excludeSymbol) && ($excludeSymbolFile ne ""))
{   $excludeSymbolFileHandle    = upload("excludeSymbolFile");
    $excludeCustomText          = join ("", <$excludeSymbolFileHandle>);
}
my $includeSymbol               = param("includeSymbol");  
my $includeSymbolFile           = param("includeSymbolFile");
my $includeSymbolFileHandle     = '';
my $includeCustomText           = '';
if (($includeSymbol) && ($includeSymbolFile ne ""))
{   $includeSymbolFileHandle    = upload("includeSymbolFile");
    $includeCustomText          = join ("", <$includeSymbolFileHandle>);
}

my $miningMode					= param("miningMode");
my $speciesExtension			= param("speciesExtension");
                                             
                                             
#my $fileContent     = '';   
#my $shortFileName   = $fileNameFull;               
#   $shortFileName   =~ s/.*[\/\\](.*)/$1/;
#my $fileHandle      = '';

my @errorMessage    = ();
my @targetPMIDs     = ();
my $queueSuccess    = 0;
my $passCheckResult = 1;


# email
if ((not defined $email) || ($email !~ /\S/))
{   push @errorMessage, "E-mail is empty.";
}else
{   if ($email =~ /^\w+\@.*\..*/)
    {   # This is a profer email address
    }else
    {   push @errorMessage, "E-mail format is unacceptable.";
    	$passCheckResult	= 0;
    }
}

# query name
if ((not defined $queryName) || ($queryName !~ /\S/))
{  	push @errorMessage, "Query/List name is empty.";
	$passCheckResult	= 0;
}


#  Check scoreThreshold
if ((defined $scoreThreshold) && ($scoreThreshold ne "") && 
	(is_number($scoreThreshold)) && ($scoreThreshold >=0))
{	
}else
{	push @errorMessage, "Score Threshold should be a number.";
}


#  -------------------------------------------------------------------------
#  Section 3 optional filters
#  -------------------------------------------------------------------------

# query string or list text or file name
if (($queryString !~ /\S/) && ($listText !~ /\S/) && ($fileNameFull !~ /\S/))
{  push @errorMessage, "PubMed query / ID list / file are all empty.";
}else
{   if ($passCheckResult)
    {   ($userName, $maxDoc, $maxNewDoc, $userInstitute) 	= get_realname_by_email($email);
    	# Pubmed query is defined
        if ((defined $queryString) && ($queryString =~ /\S/))
        {   my ($tmpStatus, $fetchedString, $count, $pmidArrRef) = search_entrez_with_pubmed_query ($queryString);
            # Error case: $tmpStatus
            #   -1 ==> query failed.
            #    0 ==> query successful but no pmid result
            #    1 ==> query successful and retrieved pmids
            if ($tmpStatus == -1)
            {   push @errorMessage, "Your query failed. Check your internet connection / NCBI server are all okay.";
            }elsif ($tmpStatus == 0)
            {   push @errorMessage, "Your query resulted in <b>0</b> document. Click 'PREVIEW' button to see if there is really no document from NCBI PubMed with your query string.";
            }else
            {   if ($miningMode eq 'NCBIGene2PubMed')
            	{	# Check the number of document and user level
		        	if ($maxDoc < $count)
		        	{   push @errorMessage, "The query returned $count documents, which is more than your allowed maximum $maxDoc at a time<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	if (not defined $errorMessage[0])
		        	{	queue_gene2pubmed_generif_query ($email, $userName, $queryName, $queryString, $fetchedString, $count, $pmidArrRef, 
		        								"EntrezQuery", $miningMode, $speciesExtension, $tmpLocalURL);
		        		$queueSuccess = 1;
		        	}
            	}elsif ($miningMode eq 'NCBIGeneRIF')
            	{	# Check the number of document and user level
		        	if ($maxDoc < $count)
		        	{   push @errorMessage, "The query returned $count documents, which is more than your allowed maximum $maxDoc at a time<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	if (not defined $errorMessage[0])
		        	{	queue_gene2pubmed_generif_query ($email, $userName, $queryName, $queryString, $fetchedString, $count, $pmidArrRef, 
		        								"EntrezQuery", $miningMode, $speciesExtension, $tmpLocalURL);
		        		$queueSuccess = 1;
		        	}
            	}else
            	{	# Query was successful and got PMIDs
		        	my ($newDocCount) = calculate_new_document_count($pmidArrRef);
		        	          	
		        	# Check the number of new document and user level
		        	if ($maxNewDoc < $newDocCount)
		        	{   push @errorMessage, "The query returned $count documents, among which $newDocCount are new to SciMiner.<br>".
		        							"You are only allowed to run a maximum of $maxNewDoc new documents at a time.<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	
		            # Now, it's time to process the retireved PMIDs
		            #print "Query string is : <b>".$queryString."</b><BR><br>";
		            if (not defined $errorMessage[0])
		            {   process_retrieved_PMIDs ($email, $userName, $queryName, $queryString, $fetchedString, $count, $pmidArrRef, "EntrezQuery", 
		                                         $ignoreName, $ignoreCustomText, $excludeSymbol, $excludeCustomText, $includeSymbol, $includeCustomText,
		                                         $useLengthOption, $wordLengthThreshold, $phenotypeOnlyFilter, $tmpLocalURL, $newDocCount, 
		                                         $useScoreThreshold, $scoreThreshold, $miningMode, $speciesExtension );
		                $queueSuccess = 1;
		            }
            	}
           }
        }elsif ((defined $listText) && ($listText =~ /\S/))
        {   # if list text is defined, then use it
        
            # Check the text for proper format
            # check_list_text
            
            # process_PMID_list_text
            my ($count, $pmidArrRef) = process_PMID_list_text ($listText);
            
            # Check the count and determine whether to proceed
            if ($count == 0)
            {   push @errorMessage, "Your PMID list doesn't contain valid ID";
            }else
            {   if ($miningMode eq 'NCBIGene2PubMed')
            	{	# Check the number of document and user level
		        	if ($maxDoc < $count)
		        	{   push @errorMessage, "The query returned $count documents, which is more than your allowed maximum $maxDoc at a time<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	if (not defined $errorMessage[0])
		        	{	queue_gene2pubmed_generif_query ($email, $userName, $queryName, " ", $listText, $count, $pmidArrRef, "pmidList", 
		        								 $miningMode, $speciesExtension, $tmpLocalURL);
		        		$queueSuccess = 1;
		        	}
            	}elsif ($miningMode eq 'NCBIGeneRIF')
            	{	# Check the number of document and user level
		        	if ($maxDoc < $count)
		        	{   push @errorMessage, "The query returned $count documents, which is more than your allowed maximum $maxDoc at a time<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	if (not defined $errorMessage[0])
		        	{	queue_gene2pubmed_generif_query ($email, $userName, $queryName, " ", $listText, $count, $pmidArrRef, "pmidList", 
		        							 $miningMode, $speciesExtension, $tmpLocalURL);
		        		$queueSuccess = 1; 
		        	}
            	}else
            	{	# Query was successful and got PMIDs
		        	my ($newDocCount) = calculate_new_document_count($pmidArrRef);
		        	          	
		        	# Check the number of new document and user level
		        	if ($maxNewDoc < $newDocCount)
		        	{   push @errorMessage, "The query returned $count documents, among which $newDocCount are new to SciMiner.<br>".
		        							"You are only allowed to run a maximum of $maxNewDoc new documents at a time.<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	
		        	if (not defined $errorMessage[0])
		            {   process_retrieved_PMIDs ($email, $userName, $queryName, " ", $listText, $count, $pmidArrRef, "pmidList", 
		                                         $ignoreName, $ignoreCustomText, $excludeSymbol, $excludeCustomText, $includeSymbol, $includeCustomText,
		                                         $useLengthOption, $wordLengthThreshold, $phenotypeOnlyFilter, $tmpLocalURL, $newDocCount, 
		                                         $useScoreThreshold, $scoreThreshold, $miningMode, $speciesExtension );
		                $queueSuccess = 1;
		            }
            	}
            }
        }elsif ((defined $fileNameFull) && ($fileNameFull ne ""))
        {   # Process with a file content
            $listText = join("",<$uploadFileHandle>);
            my ($count, $pmidArrRef) = process_PMID_list_text ($listText);

            # Check the count and determine whether to proceed
            if ($count == 0)
            {   push @errorMessage, "Your PMID list doesn't contain valid ID";
            }else
            {   if ($miningMode eq 'NCBIGene2PubMed')
            	{	# Check the number of document and user level
		        	if ($maxDoc < $count)
		        	{   push @errorMessage, "The query returned $count documents, which is more than your allowed maximum $maxDoc at a time<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	if (not defined $errorMessage[0])
		        	{	queue_gene2pubmed_generif_query ($email, $userName, $queryName, " ", $listText, $count, $pmidArrRef, "ListFile", 
            									 $miningMode, $speciesExtension, $tmpLocalURL);
            			$queueSuccess = 1;
		        	}
            	}elsif ($miningMode eq 'NCBIGeneRIF')
            	{	# Check the number of document and user level
		        	if ($maxDoc < $count)
		        	{   push @errorMessage, "The query returned $count documents, which is more than your allowed maximum $maxDoc at a time<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	if (not defined $errorMessage[0])
		        	{	queue_gene2pubmed_generif_query ($email, $userName, $queryName, " ", $listText, $count, $pmidArrRef, "ListFile", 
		        								 $miningMode, $speciesExtension, $tmpLocalURL);
		        		$queueSuccess = 1;
		        	}
            	}else
            	{	# Query was successful and got PMIDs
		        	my ($newDocCount) = calculate_new_document_count($pmidArrRef);
		        	          	
		        	# Check the number of new document and user level
		        	if ($maxNewDoc < $newDocCount)
		        	{   push @errorMessage, "The query returned $count documents, among which $newDocCount are new to SciMiner.<br>".
		        							"You are only allowed to run a maximum of $maxNewDoc new documents at a time.<br>".
		        	                        "-- Try to split your query to reduce the number or ask the administrator to increate your maximum.<br>";
		        	}
		        	
		            if (not defined $errorMessage[0])
		            {   process_retrieved_PMIDs ($email, $userName, $queryName, " ", $listText, $count, $pmidArrRef, "ListFile", 
		                                         $ignoreName, $ignoreCustomText, $excludeSymbol, $excludeCustomText, $includeSymbol, $includeCustomText,
		                                         $useLengthOption, $wordLengthThreshold , $phenotypeOnlyFilter, $tmpLocalURL, $newDocCount, 
		                                         $useScoreThreshold, $scoreThreshold, $miningMode, $speciesExtension );
		                $queueSuccess = 1;
		            }
            	}
            }
        }
    }
}




# Check for any error message
if (defined $errorMessage[0])
{   display_errorMessage_SciMiner_CGI(\@errorMessage);
}


if (! $queueSuccess)
{   print_form();
}

print "";    
print end_html;

#
sub print_SciMiner_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>SciMiner Query Submission</U></b></p>
           ";

}

#<TMPL_VAR NAME=\"REALNAME\">
sub print_form{
print "<body bgcolor=\"#EAF4F4\">
<script type=\"text/javascript\" src=\"wz_tooltip.js\"></script>


<p class=\"titleBarName1\">(<b>Instruction</b>): Click <a href=\"Files/SciMiner_User_Manual.pdf\"><b>HERE</b></a> for detailed help or move mouse pointer around to get a quick tip.<br> &nbsp;&nbsp;&nbsp;1) Name your query and enter your Pubmed search terms or provide PMIDs directly. <br> &nbsp;&nbsp;&nbsp;2) Submit your query, review the result, and correct wrongfully identified targets if necessary. <br> &nbsp;&nbsp;&nbsp;3) Re-run the same query to get an updated target identification results, if necesary with modified advanced options and user filters.</p>

<form action='sciminer.cgi' method='POST' ENCTYPE='multipart/form-data'>

<p class=\"titleBarName1\">(<b>Section1</b>) Name your query.<br>
&nbsp;&nbsp; Query name : <INPUT TYPE='text' NAME='queryName' value='' size=\"25\" onmouseover=\"Tip('Give a name to your query to distinguish this from other queries. <br> ex) ALS and ROS 11-05-2008')\" onmouseout=\"UnTip()\"><br></p>
<INPUT TYPE=\"HIDDEN\" NAME=\"email\" VALUE=\"$email\">
<input type=\"hidden\" name=\"userName\" value=\"$userName\">

<p class=\"titleBarName1\">(<b>Section2</b>) Enter your query or provide PMIDs<br>
1) NCBI Entrez PubMed search term(s)<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE='text' NAME='queryString' size=\"35\" onmouseover=\"Tip('Enter your Entrez PubMed search terms of your interest.<br>Papers are retrieved based on the PubMed search result of your query.<br>Click <b>&quot;PREVIEW&quot;</b> to see how many papers your query will result in.')\" onmouseout=\"UnTip()\">&nbsp;&nbsp;&nbsp;<a href=\"javascript:ncbi_preview_window();\" onmouseover=\"Tip('We strongly recommend you to check your by clicking <b>PREVIEW</b> before submitting your query<br> to see how big corpus your current query would be.<br><br>Note that most users are limited in their <br><b>total number of papers</b> and the number of <b>new papers</b> to SciMiner <b>per query</b>. <br><br>If you need to run a big query beyond your limit, <br> 1) Obtain all of PMIDs from PubMed and split into smaller sets, then run SciMiner on each set. <br> &nbsp;&nbsp;you can merge them after each set is finished. <br> 2) Contact the system administrator to increase your limit. <br><br> The limit has been implemented to prevent a single user from taking up all SciMiner capacity over a long period.')\" onmouseout=\"UnTip()\"><b>PREVIEW</b></a>&nbsp;&nbsp;&nbsp;(ex) &quot;Amyotrophic lateral sclerosis&quot;[MeSH] AND &quot;Reactive Oxygen Species&quot;[MeSH]
</p>


<a id=\"flag1\" href=\"#\" onclick=\"showhide('div1','flag1', 'advanced options');\" class=\"smallTextBold2\" onmouseover=\"Tip('Click here to <b>SHOW</b> or <b>HIDE</b> advanced options.')\" onmouseout=\"UnTip()\">SHOW advanced options!</a>
<div id=\"div1\" style=\"display:none\">
<p class=\"titleBarName1\">
2) List of PMIDs<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<textarea name='listText' rows=\"4\" cols=\"40\" onmouseover=\"Tip('Enter your PMIDs here one ID per line.')\" onmouseout=\"UnTip()\"></textarea><br>
3) Browse your PMID list file<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE='file' NAME='uploadFileName' size=\"35\" onmouseover=\"Tip('Select a text file with PMIDs. <br> Each line should contain only one PMID.')\" onmouseout=\"UnTip()\"></p>

<p class=\"titleBarName1\">(<b>Section3</b>) SciMiner Mining Mode </font> (*<a href=\"https://www.ncbi.nlm.nih.gov/gene/\">NCBI Gene2PubMed and GeneRIF</a> involve no text mining)<br>
<table border=\"1\">
	<tr>
		<th width=\"100\" class=\"tableHeader1\" onmouseover=\"Tip('You can choose the way how targets are searched from papers.<br><br><b>SciMiner text mining</b>: Default SciMiner text mining method to identify targets<br><b>NCBI Gene2PubMed</b>: Use NCBI Gene2PubMed in the Entrez Gene database. No text mining is involved<br><b>NCBI GeneRIF</b>: Use NCBI GeneRIF in the Entrez Gene database<br><br>Here are descriptions from the NCBI Entrez Database regarding the two NCBI resources<br><br><img src=&quot;ImagesBig/NCBIResDesc.jpg&quot; height=&quot;250&quot;  width=&quot;650&quot;')\" onmouseout=\"UnTip()\">
			Mining mode
		</th>	
		<td width=\"150\"  class=\"tableHeader1\" onmouseover=\"Tip('You can choose the way how targets are searched from papers.<br><br><b>SciMiner text mining</b>: Default SciMiner text mining method to identify targets<br><b>NCBI Gene2PubMed</b>: Use NCBI Gene2PubMed in the Entrez Gene database. No text mining is involved<br><b>NCBI GeneRIF</b>: Use NCBI GeneRIF in the Entrez Gene database<br><br>Here are descriptions from the NCBI Entrez Database regarding the two NCBI resources<br><br><img src=&quot;ImagesBig/NCBIResDesc.jpg&quot; height=&quot;250&quot;  width=&quot;650&quot;')\" onmouseout=\"UnTip()\">
			<select name=\"miningMode\" size=\"1\">
                <option selected value=\"SciMinerMining\">SciMiner text mining</option>
                <option value=\"NCBIGene2PubMed\">NCBI's Gene2PubMed</option>
                <option value=\"NCBIGeneRIF\">NCBI's GeneRIF</option>
			</select>
		</td>	
		<th width=\"200\" class=\"tableHeader1\" onmouseover=\"Tip('<b>This only applies to the two NCBI resource based method</b>.<br>Genes from non-Human species can be mapped to Human by NCBI HomoloGene data.')\" onmouseout=\"UnTip()\">
			Species extension by HomoloGene
		</th>
		<td width=\"100\" onmouseover=\"Tip('<b>This only applies to the two NCBI resource based method</b>.<br>Genes from non-Human species can be mapped to Human by NCBI HomoloGene data.')\" onmouseout=\"UnTip()\">
			<select name=\"speciesExtension\" size=\"1\">
                <option selected value=\"speciesExtension\">Extend by HomoloGene</option>
                <option value=\"humanOnly\">Only explicit human targets</option>
			</select>
		</td>
	</tr>
</table>
</p>
<p class=\"titleBarName1\">(<b>Section4</b>) Additional options for SciMiner text mining<br>

<table border=\"0\" style=\"text-align:left\">
	<tr onmouseover=\"Tip('<b>IGNORE</b>: You may provide SciMiner-identified gene/protein names (<b>matching terms</b>) that you find inappropriate.<br>These names will be ignored and not be reported in the final report.<br><br>Usually these can be ambiguous/unspecific names in SciMiner dictionary that have not been cleaned yet.<br>Click <b>Default</b> to see the content of the default ignore filter.<br><br>Your own filter may include only those which are not in the default list.')\" onmouseout=\"UnTip()\">
		<td>
			<input type=\"checkbox\" name=\"ignoreName\">Names to be <b>ignored</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			<input type=\"file\" name=\"IgnoreListFile\" size=\"20\">  &nbsp;&nbsp;&nbsp;(<a href=\"Files/IGNORE_default.txt\" onmouseover=\"Tip('.')\" onmouseout=\"UnTip()\">Default</a> by SciMiner v2.2)
		</td>
	</tr>
	
	<tr onmouseover=\"Tip('<b>EXCLUDE</b>: You may provide SciMiner-identified SYMBOLs (<b>matching terms</b>) that you find inappropriate.<br>These symbols will be excluded if exclusion conditions are met.<br><br>EX) <b>SDS&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;sodium dodecyl sulfate</b><br><br>If SciMiner finds SDS and sodium dodecyl sulfate <b>in the same document</b><br>this identification of SDS will be excluded. The default assignment of SDS is <b>serine dehydratase.</b><br><br>Click <b>Default</b> to see the content of the default EXCLUDE filter.<br><br>Your own filter may include only those which are not in the default list.')\" onmouseout=\"UnTip()\">
		<td>
			<input type=\"checkbox\" name=\"excludeSymbol\">Symbols to be <b>excluded</b>&nbsp;&nbsp;&nbsp;&nbsp;
			<input type=\"file\" name=\"excludeSymbolFile\" size=\"20\"> &nbsp;&nbsp;&nbsp;(<a href=\"Files/EXCLUDE_default.txt\">Default</a> by SciMiner v2.2)
		</td>
		
	</tr>
		
	<tr onmouseover=\"Tip('<b>INCLUDE</b>: Identified symbols with SciMiner confidence score of <b>0</b> are not included in the final report. <br>However, you can force SciMiner to include them when conditions are met.<br><br>This feature might be useful for symbols which you are quite sure to be legitimate gene symbols <br>but happen to have SciMiner score of <b>0</b> due to lack of supporting longer description (names) in the same document.<br><br>If MedLine abstract is the only available text for a given paper, <br>it is likely that many of identified symbols are likely to have SciMiner score of 0.<br><br>Click <b>Default</b> to see the content of the default EXCLUDE filter.<br><br>Your own filter may include only those which are not in the default list.')\" onmouseout=\"UnTip()\">
		<td>
			<input type=\"checkbox\" name=\"includeSymbol\">Symbols to be <b>included</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			<input type=\"file\" name=\"includeSymbolFile\" size=\"20\"> &nbsp;&nbsp;&nbsp;(<a href=\"Files/INCLUDE_default.txt\">Default</a> by SciMiner v2.2)
		</td>
	</tr>
	
	<tr onmouseover=\"Tip('You may use this option to include any identified symbol longer than specified characters.<br>Longer symbols are more likely to be true gene symbols.')\" onmouseout=\"UnTip()\">
		<td>
			<input type=\"checkbox\" name=\"useLengthOption\" value=\"1\" checked>Include any gene symbol longer than 
			<INPUT TYPE='text' NAME=\"wordLengthThreshold\" size=\"2\" value=\"6\">, unless specified by the above filters
		</td>
	</tr>
	
	<tr>
		<td onmouseover=\"Tip('You can specify SciMiner score threshold for your query. <br>Suggested thresholds are <b>0.1</b>, <b>0.3</b> and <b>0.6</b> for minimum, moderate, and high confidence respectively.<br><br>This is based on performance evaluation on BioCreative II Gene Normalization task.<br>Please, refer to the supplementary material or <b>HELP</b><br>')\" onmouseout=\"UnTip()\">
			<input type=\"hidden\" name=\"useScoreThreshold\" value=\"1\">
			<input type=\"checkbox\" name=\"useScoreThresholdDisabled\" value=\"1\" checked disabled=\"disabled\">SciMiner confidence score threshold 
			<INPUT TYPE='text' NAME=\"scoreThreshold\" size=\"2\" value=\"0.1\"> (0.1: minimum, &#x2265;0.3: moderate, &#x2265;0.6: high)
		</td>
		<td>
			<a onclick=\"openNewWindow('Files/ConfidenceScoreHelp.html');\" onmouseover=\"Tip('Click here to view more help on score threshold.')\" onmouseout=\"UnTip()\"><b><u>more on scores</u></b></a>
		</td>
	</tr>
	
	<tr onmouseover=\"Tip('Phenotype only genes do not have other functional annotation assigned.<br>You may turn this option off to see the list in the final report.')\" onmouseout=\"UnTip()\">
		<td>
			<input type=\"checkbox\" name=\"phenotypeOnlyFilter\" value=\"1\" checked>Do not include phenotype only genes &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(ex) IDDM2 (Insulin-dependent diabetes melitus 2), <br>
		 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SCZD1 (Schizophrenia disorder 1) (<b>Full list</b> <a href=\"Files/phenotypeOnlyGenes.xls\">EXCEL</a>, <a href=\"Files/phenotypeOnlyGenes.txt\">TXT</a>)
		</td>
	</tr>
</table>

</p>

</div>

<p class=\"smallText2\"><input type='submit' name='submit form'><input type=\"reset\" name=\"reset form\"></p>
<p class=\"smallText2\">* Supplementary files. You may need these files to create your own filter lists. (HUGO IDs are essential.)<br>
Better save the text files and load them in a text editor like <a href=\"http://www.ultraedit.com/\">UltraEdit</a> or <a href=\"http://www.editplus.com/\">EditPlus</a><br>
1) Full HUGO Content (<a href=\"Files/HUGO_Extended.xls\" onmouseover=\"Tip('Here are all the HUGO genes on which SciMiner is based on.')\" onmouseout=\"UnTip()\">EXCEL</a>, <a href=\"Files/HUGO_trimmed_final_default.txt\">TXT</a>)<br>
2) Unique symbols (<a href=\"Files/UNIQUESYMBOL_default.txt\" onmouseover=\"Tip('Here are all the unique symbols in SciMiner dictionary.')\" onmouseout=\"UnTip()\">TXT</a>)<br>
3) Unique names (<a href=\"Files/UNIQUENAME_default.txt\" onmouseover=\"Tip('Here are all the unique names (descriptions) in SciMiner dictionary.')\" onmouseout=\"UnTip()\">TXT</a>)<br>
 <br>
</p>
";
}





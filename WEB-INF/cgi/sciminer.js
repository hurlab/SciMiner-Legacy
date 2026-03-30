// -----------------------------------------------------------------------------
//  						sciminer.js
// -----------------------------------------------------------------------------
//                                         Written By Junguk HUR
//                                         juhur @ umich . edu
//
// 	Collection of Javascript functions for SciMiner
//
// -----------------------------------------------------------------------------



var openImg 	= new Image();
openImg.src 	= "/SciMiner1.1/SciMiner/Images/open.gif";
var closedImg 	= new Image();
closedImg.src 	= "/SciMiner1.1/SciMiner/Images/closed.gif";
var docImg 		= new Image();
docImg.src 		= "/SciMiner1.1/SciMiner/Images/doc.gif";

function showBranch(branch)
{
	var objBranch = document.getElementById(branch).style;
	if(objBranch.display=="block")
		objBranch.display="none";
	else
		objBranch.display="block";
}

function swapFolder(img)
{
	objImg = document.getElementById(img);
	if(objImg.src.indexOf('closed.gif')>-1)
		objImg.src = openImg.src;
	else
		objImg.src = closedImg.src;
}


function switch_to_simple_mode_on_load ()
{	show_hide_column('geneEnrichmentTable','5_6_7_8_9_10_13');
	show_hide_column('top10MeSHTableLong','3_4_5_6_7_8_11');
	show_hide_column('top10MeSHTableShort','3_4_5_8');
	show_hide_column('top10PathwayTableLong','4_5_6_7_8_9_12_13');
	show_hide_column('top10PathwayTableShort','4_5_6_9');
	show_hide_column('BPLevel','5_6_7_10');
	show_hide_column('BPExplicit','5_6_7_10');
	show_hide_column('BPFull','5_6_7_10');
	show_hide_column('MFLevel','5_6_7_10');
	show_hide_column('MFExplicit','5_6_7_10');
	show_hide_column('MFFull','5_6_7_10');
	show_hide_column('CCLevel','5_6_7_10');
	show_hide_column('CCExplicit','5_6_7_10');
	show_hide_column('CCFull','5_6_7_10');
}


// **************************  Table expand/hide      **************************
function hide_show(nr_of_elements)
{	var a = 1;
    while(a <= nr_of_elements){
        var element_name = "cell" + a;
        var element = getElementById(element_name);
        if(element.style.display == ""){
            element.style.display = "none";}
        else{
            element.style.display = "";}
    a++;}
    return 0;
}


function show_hide_column(id_of_table, column_string) 
{	// This function has been obtained from 
	// http://www.adp-gmbh.ch/web/js/hiding_column.html
	
	var col_no_arr		= column_string.split('_');
	var tbl  = document.getElementById(id_of_table);
	if (undefined == tbl)
	{	return 0;
	}
	var rows = tbl.getElementsByTagName('tr');
	
	// run on the first column to get the status
	var firstCels 	= rows[0].getElementsByTagName('th');
	var col_str_arr	= new Array(firstCels.length);
	

	for (var colIndex = 0; colIndex< firstCels.length ; colIndex++)
	{	col_str_arr[colIndex] = firstCels[colIndex].style.display ;
	}
	
	for (var selCol=0; selCol < col_no_arr.length; selCol++)
	{	if (col_str_arr[col_no_arr[selCol]] == "none")
		{	col_str_arr[col_no_arr[selCol]]	= "";
		}else
		{	col_str_arr[col_no_arr[selCol]]	= "none";
		}
	}

	// change the style for every cell
	for (var colIndex = 0; colIndex< firstCels.length ; colIndex++)
	{	firstCels[colIndex].style.display = col_str_arr[colIndex];
	}
	
	for (var row=1; row<rows.length;row++) 
	{	var cels = rows[row].getElementsByTagName('td')
	  	for (var colIndex = 0; colIndex<cels.length; colIndex++)
	  	{	cels[colIndex].style.display = col_str_arr[colIndex];
	  	}
	}


	/*		Original Script 
			  function show_hide_column(col_no, do_show) {

			var stl;
			if (do_show) stl = 'block'
			else         stl = 'none';

			var tbl  = document.getElementById('id_of_table');
			var rows = tbl.getElementsByTagName('tr');

			for (var row=0; row<rows.length;row++) {
			  var cels = rows[row].getElementsByTagName('td')
			  cels[col_no].style.display=stl;
			}
		  }
	*/
}


// **************************  ncbi_preview_window()  **************************
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
            obj2.innerHTML = "[ HIDE " + message + " ]";
        } else {
            obj.style.display = "none";
            obj2.innerHTML = "[ SHOW " + message + " ]";
        }
    }
}

function network_generate_open_window()
{
	var minPaperMethodString		= document.getElementsByName("MinPaperMethod")[0].value;
	var minTopPaperString			= document.getElementsByName("MinTopPaper")[0].value;
	var relPathString				= document.getElementsByName("RelPath")[0].value;
	var merSumFileNameString		= document.getElementsByName("MerSumFileName")[0].value;
	var randomNumberString			= document.getElementsByName("RandomNumber")[0].value;
	var totalPMIDString				= document.getElementsByName("TotalPMID")[0].value;

	randomNumberString				= Math.floor(Math.random()*1000000000)

	// Call generateNetworkJSON.cgi which generates JSON data and
	// redirects to the Cytoscape.js network viewer (network_viewer.html)
	var hostURL						= window.location.host;
	var protocol					= window.location.protocol;
	var generateURL					= protocol + '//' + hostURL + '/SciMiner/' +
									  "generateNetworkJSON.cgi?MinPaperMethod=" + minPaperMethodString +
									  "&MinTopPaper=" 		+ minTopPaperString +
									  "&RelPath=" 			+ relPathString +
									  "&MerSumFileName=" 	+ merSumFileNameString +
									  "&RandomNumber=" 		+ randomNumberString +
									  "&TotalPMID=" 		+ totalPMIDString;

	// Open network viewer in a new window/tab
	window.open(generateURL, 'SciMiner_Network', 'width=1200,height=800,resizable=yes,scrollbars=yes');
}   // network_generate_open_window()





function download_symbols_open_window()
{	
	var minPaperMethodString		= document.getElementsByName("MinPaperMethod")[0].value;
	var minTopPaperString			= document.getElementsByName("MinTopPaper")[0].value;
	var relPathString				= document.getElementsByName("RelPath")[0].value;
	var merSumFileNameString		= document.getElementsByName("MerSumFileName")[0].value;
	var randomNumberString			= document.getElementsByName("RandomNumber")[0].value;
	var totalPMIDString				= document.getElementsByName("TotalPMID")[0].value;

	randomNumberString				= Math.floor(Math.random()*1000000000)

	// Link to the generated URL
	var hostURL						= window.location.host;
	var fullURLListFile				= 'http://' + hostURL + '/SciMiner/' + relPathString + 'Temp/' + randomNumberString;


	var generateURL					= 'http://' + hostURL + '/SciMiner/' + "generateNetworkShow.cgi?MinPaperMethod=" + minPaperMethodString + 
									  "&MinTopPaper=" 		+ minTopPaperString +
									  "&RelPath=" 			+ relPathString + 
									  "&MerSumFileName=" 	+ merSumFileNameString + 
									  "&RandomNumber=" 		+ randomNumberString +
									  "&TotalPMID=" 		+ totalPMIDString;

	// Call generateNetwork.cgi
	window.open(generateURL);
	
	
}   // network_generate_open_window()


function generate_pmid_list_html(tmpValueString, typeNameString, typeColumnString, currentBaseDirString, resultBaseDirString, extHugoIDString, symbolString)
{	// create CGI URL
	var hostURL						= window.location.host;
	var generateURL					= 'http://' + hostURL + '/SciMiner/' + "generatePMIDListHTML.cgi?currentBaseDir=" + currentBaseDirString + 
									  "&resultBaseDir=" 		+ resultBaseDirString +
									  "&tmpValue=" 				+ tmpValueString + 
  									  "&typeName=" 				+ typeNameString +
									  "&typeColumn=" 			+ typeColumnString +
									  "&extHugoID="				+ extHugoIDString +
									  "&hugoSymbol="			+ symbolString;
									  
	// call the cgi
	window.open(generateURL);
}

function generate_pmid_list_from_mesh_html(tmpValueString, typeNameString, typeColumnString, currentBaseDirString, resultBaseDirString, meshTreeCodeString, meshDescString)
{	// create CGI URL
	var hostURL						= window.location.host;
	var generateURL					= 'http://' + hostURL + '/SciMiner/' + "generatePMIDListFromMeSHHTML.cgi?currentBaseDir=" + currentBaseDirString + 
									  "&resultBaseDir=" 		+ resultBaseDirString +
									  "&tmpValue=" 				+ tmpValueString + 
  									  "&typeName=" 				+ typeNameString +
									  "&typeColumn=" 			+ typeColumnString +
									  "&meshTreeCode="			+ meshTreeCodeString +
									  "&meshDesc="				+ meshDescString;
									  
	// call the cgi
	window.open(generateURL);
}


function generate_pmid_list_from_mesh_html_simplified(tmpValueString, typeNameString, typeColumnString, currentBaseDirString, resultBaseDirString, meshDescIDString)
{	// create CGI URL
	var hostURL						= window.location.host;
	var generateURL					= 'http://' + hostURL + '/SciMiner/' + "generatePMIDListFromMeSHHTMLSimple.cgi?" + 
									  "currentBaseDir=" 		+ currentBaseDirString + 
									  "&resultBaseDir=" 		+ resultBaseDirString +
									  "&tmpValue=" 				+ tmpValueString + 
  									  "&typeName=" 				+ typeNameString +
									  "&typeColumn=" 			+ typeColumnString +
									  "&meshDescID="			+ meshDescIDString ;
									  
	// call the cgi
	window.open(generateURL);
}


function generate_gene_list_html(tmpValueString, typeNameString, typeColumnString, currentBaseDirString, resultBaseDirString, pathwayIDString, pathNameString)
{	// create CGI URL
	var hostURL						= window.location.host;
	var generateURL					= 'http://' + hostURL + '/SciMiner/' + "generateGeneListHTML.cgi?currentBaseDir=" + currentBaseDirString + 
									  "&resultBaseDir=" 		+ resultBaseDirString +
									  "&tmpValue=" 				+ tmpValueString + 
  									  "&typeName=" 				+ typeNameString +
									  "&typeColumn=" 			+ typeColumnString +
									  "&pathwayID="				+ pathwayIDString +
									  "&pathName="				+ pathNameString;
									  
	// call the cgi
	window.open(generateURL);
}

function generate_gene_list_from_pathway_bminus_html(tmpValueString, typeNameString, typeColumnString, currentBaseDirString, resultBaseDirString, pathwayIDString, pathNameString)
{	// create CGI URL
	var hostURL						= window.location.host;
	var generateURL					= 'http://' + hostURL + '/SciMiner/' + "generateGeneListHTMLFull.cgi?currentBaseDir=" + currentBaseDirString + 
									  "&resultBaseDir=" 		+ resultBaseDirString +
									  "&tmpValue=" 				+ tmpValueString + 
  									  "&typeName=" 				+ typeNameString +
									  "&typeColumn=" 			+ typeColumnString +
									  "&pathwayID="				+ pathwayIDString +
									  "&pathName="				+ pathNameString;
									  
	// call the cgi
	window.open(generateURL);
}

function generate_go_detail_html(tmpGOIDString, tmpDirBaseNameString, tmpFileBaseNameString)
{	// create CGI URL
	var hostURL						= window.location.host;
	
	var generateURL					= 'http://' + hostURL + '/SciMiner/' + 'generateGOHtml.cgi?' +
									  "goID=" 					+ tmpGOIDString +
  									  "&dirBaseName=" 			+ tmpDirBaseNameString +
									  "&fileBaseName=" 			+ tmpFileBaseNameString ;
									  
	// call the cgi
	window.open(generateURL);


}


function retrieveDocumentScript (endnoteAllStr, pmidSelectStr, fileExtensionStr, resultBaseDirStr, htmlURLStr )
{	var hostURL			= 	window.location.host;
	//window.open("http://www.google.com/search?q=" + hostURL);
	var generateURL		= 	'http://' + hostURL + '/SciMiner/' + 'retrieveDocument.cgi?' +
							"endnoteAll="			+ endnoteAllStr +
							"&pmidSelect="			+ pmidSelectStr +
							"&fileExtension="		+ fileExtensionStr +
							"&resultBaseDir="		+ resultBaseDirStr +
							"&htmlURL="				+ htmlURLStr;
		
	// call the cgi
	window.open(generateURL);					
}


function editSciMinerFinding (sen2geneID, fileNameBase, matchString, actualString, oldHUGOID)
{	var hostURL			= 	window.location.host;
	var generateURL		= 	'http://' + hostURL + '/SciMiner/' + 'editSciMinerFinding.cgi?' +
							"sen2geneID="			+ sen2geneID +
							"&fileNameBase="		+ fileNameBase +
							"&matchString="			+ matchString +
							"&oldHUGOID="			+ oldHUGOID +
							"&actualString="		+ actualString;
		
	// call the cgi
	window.open(generateURL);				
}


function editSciMinerFindingFromMergedFile (sen2geneID, fileNameBase, matchString, actualString, oldHUGOID)
{	var hostURL			= 	window.location.host;
	var generateURL		= 	'http://' + hostURL + '/SciMiner/' + 'editSciMinerFindingFromMergedFile.cgi?' +
							"sen2geneID="			+ sen2geneID +
							"&fileNameBase="		+ fileNameBase +
							"&matchString="			+ matchString +
							"&oldHUGOID="			+ oldHUGOID +
							"&actualString="		+ actualString;
		
	// call the cgi
	// self.location	= generateURL;
	window.open(generateURL);	
}

function editSciMinerFindingFromMergedFileNew (sen2geneID, fileNameBase, matchString, actualString, oldHUGOID)
{	var hostURL			= 	window.location.host;
	var generateURL		= 	'http://' + hostURL + '/SciMiner/' + 'editSciMinerFindingFromMergedFileNew.cgi?' +
							"sen2geneID="			+ sen2geneID +
							"&fileNameBase="		+ fileNameBase +
							"&matchString="			+ matchString +
							"&oldHUGOID="			+ oldHUGOID +
							"&actualString="		+ actualString;
		
	// call the cgi
	// self.location	= generateURL;
	window.open(generateURL);	
}

function generate_detailed_matrched_terms (hugoID, fileNameBase, occurCount, paperCount)
{	var hostURL			= 	window.location.host;
	var generateURL		= 	'http://' + hostURL + '/SciMiner/' + 'generateDetailedMatchedTermsPage.cgi?' +
							"hugoID="			+ hugoID +
							"&fileNameBase="		+ fileNameBase +
							"&occurCount="			+ occurCount +
							"&paperCount="			+ paperCount ;
		
	// call the cgi
	window.open(generateURL);	
}


function generate_detailed_matrched_terms_new (hugoID, fileNameBase, occurCount, paperCount)
{	var hostURL			= 	window.location.host;
	var generateURL		= 	'http://' + hostURL + '/SciMiner/' + 'generateDetailedMatchedTermsPageNew.cgi?' +
							"hugoID="			+ hugoID +
							"&fileNameBase="		+ fileNameBase +
							"&occurCount="			+ occurCount +
							"&paperCount="			+ paperCount ;
		
	// call the cgi
	window.open(generateURL);	
}



function openNCBIFulltextLink (pmidString)
{	var generateURL	= "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&retmode=ref&cmd=prlinks&id=" + pmidString;
	window.open(generateURL);
}

function openPubMedForPMID (pmidString)
{	//var generateURL	= "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&retmode=ref&cmd=prlinks&id=" + pmidString;
	var generateURL = "https://pubmed.ncbi.nlm.nih.gov/?term=" + pmidString;
	window.open(generateURL);
}

function openNewWindowsRelativeURL (relativeURL)
{	var hostURL			= 	window.location.host;
	window.open(relativeURL)
}

function openNewWindow (urlString)
{	window.open(urlString);
}


function URLOpenDelay (url)
{	setTimeout(window.open(url), 100);
	window.open("http://www.google.com");
}

function URLOpenFunc (url)
{	window.open(url);
}



#!/usr/bin/perl -w
################################################################################
#
#   	Subroutin Collection for SciMiner - Base
#	
#									Written by : Junguk Hur	
#	
################################################################################
# ------------------------------------------------------------------------------
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Specify required modules
# ------------------------------------------------------------------------------
use strict;
use warnings;
use DBI;
use Annotation::basicIO;            
use Annotation::SciMiner;  

my @pmids = ();	#15721403,15359128,14960465,123412341,123412342,15721403,18637161

#  Load working environment for ANNOTATION
my %annoENV 	= anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};

#  Connect to the SciMiner DB
my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");
my $dbh = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0})
    || die "Could not open database, ", $DBI::errstr;

#  Obtain PMIDs to update
my $sql			= "SELECT pmid, linkURLOriginal FROM document";
my $sth			= $dbh->prepare($sql);
$sth->execute();
my @row			= ();
while(@row = $sth->fetchrow_array)
{   if ((defined $row[1]) && ($row[1] ne "") && ($row[1] ne "NULL"))
    {   
    }else
    {	push @pmids, $row[0];
    }
}

Retrieve_and_Update_HTML_URL (\@pmids, $dbh);
exit;



sub Retrieve_and_Update_HTML_URL 
{	my $pmidListRef			= shift;
	my $dbh					= shift;

	use LWP::UserAgent;                 
    use LWP::Simple;

	#  Create UserAgent
    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/5.0');
    $ua->timeout(120);
    
    #  Links and directories
    my $ELINK       = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?';
		
    #  Fetch MEDLINE records
    my @PMIDList            	= @{$pmidListRef};
    my %PMID2HTMLOriginal		= ();
	my $documentsPerRetrieval	= 200;
	my $totalPMIDToBeFetched	= scalar @PMIDList;
	
	for (my $i=0; $i < $totalPMIDToBeFetched; $i += $documentsPerRetrieval)
	{	my $uppderLimit		= 0;
		if ($totalPMIDToBeFetched < ($i + $documentsPerRetrieval))
		{	$uppderLimit	= $totalPMIDToBeFetched;
		}else
		{	$uppderLimit	= $i + $documentsPerRetrieval;
		}
		
		my @PMIDSet			= ();
		my @PMIDSetForPri	= ();
		
		for (my $j=$i; $j < $uppderLimit; $j++)
		{	push @PMIDSet, $PMIDList[$j];
		}
		
		my $idString		= join (",", @PMIDSet);
		
		#  Try to fetch MEDLINE
		my $url = $ELINK."dbfrom=pubmed&retmode=ref&cmd=llinks&id=$idString";
    	my $req = HTTP::Request->new( GET => $url );
    	my $res = $ua->simple_request($req);

    	if( $res->is_success )
    	{   #  Split the retrieved into different PMIDs
    		my @blocks		= split (/<\/IdUrlSet>/, $res->content);
    		my $fileName	= '';
    		
    		for (my $p=0; $p <= $#blocks; $p++)
    		{	#  Check if there is any errorneous PMID
    			my ($status, $tmpPMID, $htmlURL) = extract_html_link ($blocks[$p]);
    			
    			#  Check the status
    			if ($status == 0)
    			{	# There is no PMID found in the block
    			}elsif ($status == 1)
    			{	# This PMID has no link at all
    			}elsif ($status == 2)
    			{	# This PMID has link found
    				# Update the server for this information
    				$dbh->do("UPDATE document SET linkURLOriginal=\"$htmlURL\" WHERE pmid = $tmpPMID");
    			}elsif ($status == 3)
    			{	# We have to run for primaryLink
    				push @PMIDSetForPri, $tmpPMID;
    			}
    		}
    	}
    	
    	if (defined $PMIDSetForPri[0])
    	{	# Perform to extract primary links
    		for (my $j = 0; $j <= $#PMIDSetForPri; $j++)
    		{	my $urlPrimary 	= $ELINK."dbfrom=pubmed&retmode=ref&cmd=prlinks&id=$PMIDSetForPri[$j]";
		    	my $reqPrimary	= HTTP::Request->new( GET => $urlPrimary);
				$res			= $ua->simple_request($reqPrimary);
    			
				#  Get the URL for article if specified by PubMed
				my $PrimaryLink	= $res->header("Location");
				if ((defined $PrimaryLink) && ($PrimaryLink ne ""))
				{	$dbh->do("UPDATE document SET linkURLOriginal=\"$PrimaryLink\" WHERE pmid = $PMIDSetForPri[$j]");
				}
    		}
    	}
	}
}

exit;






sub extract_html_link
{	my $content			= shift;

	my $articleURL      = '';
	my $PMCLink			= '';
	my $PrimaryLink		= '';
	my $PMID			= '';
	
	$content	=~ s/\r|\n//g;
    $content	=~ s/&amp;/&/g;
   
   	#  Get the PMID
	if ($content =~ /<Id>(\d+)<\/Id>/)
	{	$PMID			= $1;
	}else
	{	return (0, "", "");
	}
   	
   	#  Check the links
   	if ($content =~ /<Info>No links<\/Info>/)
   	{	return(1, $PMID, "");
   	}elsif ($content =~ /(http:\/\/www.pubmedcentral\.nih\.gov\/articlerender\.fcgi\?\S+)<\/Url>/)
    {   $PMCLink    	= $1;
    }else
    {   #  Get the primary link
	    while()
	    {   if ($content =~ /<ObjUrl>(.*?)<\/ObjUrl>/)
	    	{   $content = $';
	    		my $localString	= $1;

	    		if ($localString =~ /<Url>(http:\/\/\S+)<\/Url>.*?<SubjectType>(.*?)<\/SubjectType>.*?<NameAbbr>(.*?)<\/NameAbbr>/)
	    		{	my $tmpURL	    = $1;
	    			my $tmpType	    = $2;
	    			my $nameAbbr    = $3;
	    			
		    		if (($tmpType =~ /publishers/i) || ($tmpType =~ /providers/i))
	    			{	# Only care the first publisher/provider type URL
	    				if ($PrimaryLink eq "")
	    				{   $PrimaryLink	= $tmpURL;
	    				}else
	    				{   #  Replace the current PrimaryLink when 'HighWire' is available
	    				    if ($nameAbbr eq 'HighWire')
	    				    {   $PrimaryLink    = $tmpURL;
	    				    }
	    				}
	    			}   
	    		}else
	    		{   #  Wrong format. Ignore
	    		}
	    	}else
	    	{   last;
	    	}
	    }
    }
    
    if ($PMCLink)
	{	return(2, $PMID, $PMCLink);
	}else
	{	if ($PrimaryLink)
		{	return(2, $PMID, $PrimaryLink);
		}else
		{	return(3, $PMID, "");
		}
	}
}

















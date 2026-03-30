#!/usr/bin/perl
# -----------------------------------------------------------------------------
#                        elsevierParse.pl
#                                                   Junguk Hur
#                                                   juhur <at> umich <dot> edu
#
# This script will parse ELSEVIER fulltext HTML document to XML.
#
#   Usage: >./elsevierParse.pl <HTML> > XMLFILE
#
# Prints standardized XML format from ELSEVIER HTML full-text article.
# This script has been adopted and modified from Dr. David States' pmcParse.pl
#
# NOTE: 1) If there is no 'Article Outline', parsing is aborted since
#          it's extremely likely that the html is not a full text document.
#
#       2) If there is no 'References</span>', parsing is aborted since
#          it's also likely that the html is not a full text document. 
#
# CHANGE:  12/03/2007: There has been changes in the code to cope with the 
#                      changes in the Elsevier document HTML format.
# -----------------------------------------------------------------------------
#use warnings;
use strict;

# Load HTML file
open( HTML, $ARGV[0] ) || die "! can't open $ARGV[0]..\n";
my @HTMLfile = <HTML>;
my ($PMID) = $ARGV[0] =~ m|(\d+).htm|;

foreach my $line (@HTMLfile)
{   chomp $line; 
}

# Check whether this is an elsevier document
my $htmlArticle = join(' ', @HTMLfile);
if ($htmlArticle !~ /<title>ScienceDirect/)
{   # This is not a ELSEVIER document.
    exit;
}


# Perform parsing
my %article = %{ParseElseVierV2($htmlArticle)};
my $keyCountV2  = scalar (keys %article);
my $keyCountV1  = 0;
# If we've still only got one key...there was an error in the parse...

if( $keyCountV2 <= 1 )
{   # Try old parser
    %article = %{ParseElseVier($htmlArticle)};
    if (scalar (keys(%article)) <= 1)
    {   exit;
    }
}else
{   # There are still some anchors, but try old parser
    my %articleOld  = %{ParseElseVier($htmlArticle)};
    $keyCountV1 = scalar (keys %articleOld);
    
    if ($keyCountV2 < $keyCountV1)
    {   %article = %articleOld;
        # print "old parser is better\n";
    }
}



print "<DOC>\n<PMID>$PMID<\/PMID>\n";

# Check whether this is required. #
foreach my $section( sort( { $article{$a}->{order} <=> $article{$b}->{order} } keys( %article) ) )
{   my $modified = $article{$section}->{text};
    $modified =~ s/ \< / \&lt; /g;
	$modified =~ s/ \& / \&amp\; /g;
	print "<$section>\n$modified<\/$section>\n\n";
}

print "</DOC>";
exit;




#  sub ParseElseVierV2 is created on 12/03/2007
#  To cope with the changes the sciencedirect has undergone with their webpages
#  Major changes: 1) Related documents to be removed
#                 2) changes in the tags (no more frequent use of span)

sub ParseElseVierV2()
{   my $htmlArticle = shift;
    my %article = (); 
    my @sideTables = (); 
    my %sectionAnchors = ();


    #NEW: <h3 class="h3">Article Outline</h3><dl><dt> <a href="#SECX1">Introduction</a></dt><dt> 
    #OLD: <p><span class="h3">Article Outline</span><dl><dt> <a href="#SECX1">Introduction</a></dt><dt>
    
    # Step#1, check whether the HTML is a fulltext HTML or not
    # Fulltext ElseVier HTML seems to have 'Article outline'
    if ($htmlArticle !~ /Article Outline/)
    {   # This doesn't seem to be a real ElseVier HTMl
        exit;
    }
    my $priorArticleOutline = $`;       #`
    my $postArticleOutline = $';        #'


    # Step#2, extract the title of the paper
    #NEW: <div class="articleTitle"><p>
    #OLD: <span class="articleTitle">
    if ($priorArticleOutline =~ /articleTitle\"><p>(.*?)<\/div>/)
    {   $article{ TITLE }->{text} = CleanUp($1);
        $article{ TITLE }->{order} = 0;
    }else
    {   $article{ TITLE }->{text} = "";
        $article{ TITLE }->{order} = 0;
    }
    
    my $remainingPriorArticleOutline = $';


    # Step#3, extract abstract or background before #'Article outline#'
    #OLD: <p><span class="h3">
    #NEW: <h3 class="h3">
    
    if ($remainingPriorArticleOutline =~ /<h3 class=\"h3\">Abstract<\/h3>/)
    {   my $tmpAbstract = $';
        $tmpAbstract =~ s/<i>|<\/i>//g;
        $article{ABSTRACT}->{text} = CleanUp($tmpAbstract);
    }else
    {   $article{ABSTRACT}->{text} = '';
    }
    $article{ABSTRACT}->{order} = 1;


    # Step#4: Find '>References</span>'
    my $bodyContent = '';
    my $referenceContent = '';
    #OLD <span class="h3">References</span><p><a name="bib1">
    #NEW <h3 class="h3">References</h3><p><a name="bib1"></a>
    if ($postArticleOutline =~ /<span class=\"h\d\">References<\/span><p>/)
    {   # The remaining section is for REFERENCES
        $bodyContent = $`.$&;
        $referenceContent = $';
    }elsif ($postArticleOutline =~ /<h3 class=\"h\d\">References<\/h3></)   #<span class=\"h\d\">References<\/span><p>/)
    {   # The remaining section is for REFERENCES
        $bodyContent = $`.$&;
        $referenceContent = $';
    }else
    {   # If there is no 'References</span>', parsing is aborted since
        # it's also likely that the html is not a full text document.
        exit;
    }


    # Step#5: Extract figures and tables 
    # Figures and Tables start with 'blockquote'
    # --------------------------------------------------------------------------
    # NOTE: Table is not recognized correctly. In fact, SciMiner does not care
    #       the content in the table at all.
    my $newBodyContent = $bodyContent;
    while($newBodyContent =~ /<blockquote>(.*?)<\/blockquote>/)
    {   $newBodyContent = $`.$';
        my $tmpContent = $1;
        my $tmpTableText = '';

        if ($tmpContent =~ /<p>\s*Fig/i)
        {   # This is a figure
            if ($tmpContent =~ /<\/td><\/tr><\/table>/)
            {   $article{FIGURE}->{text} .= CleanUp("\n".$'."\n");
                $article{FIGURE}->{order} = 99;
                #print $'."\n\n\n";
            }
        }elsif ($tmpContent =~ /<p>\s*Tab/i)
        {   # This is a table
            while($tmpContent =~ /<p>(.*?)(<p>)/)
            {   my $tmpMatching = $1;
                my $postContent = $';
                if ($tmpMatching !~ /<\/a>/)
                {   if ($tmpMatching =~ /<\/div>/)
                    {   $tmpTableText .= CleanUp("<p>".$`."<p>\n");
                    }else
                    {   $tmpTableText .= CleanUp("<p>".$tmpMatching."<p>\n");
                    }
                }
                $tmpContent = "<p>".$postContent;
            }
            if ( $tmpTableText ne "")
            {   $article{TABLE}->{text} .= "\n".$tmpTableText."\n";
                $article{TABLE}->{order} = 99;
                #print $article{TABLE}->{text}."\n\n";
            }
        }
    }

    
    # Step#6: Handle remaining main body; methods, results, and discussion
    my $currentH3Anchor = '';
    my $order = 2;
    
    #  If there is no appropriate H3 level section, check only if there is probable
    #  candidate section, and put it as OTHER section.
    # OLD: 
    # NEW: <a name="SECX1"></a><h3 class="h3"> Introduction</h3>
    if ($newBodyContent !~ /<h\d class=\"h(\d)\"(>.*?)(<h\d class=\"h\d\">)/)
    {   #  There is no appropriate section found. 
        #  1) there is really nothing
        #  2) there is something without section anchor
        #  print "\n\n\n\n\n\n".$newBodyContent."\n\n\n\n\n";
        if ($newBodyContent =~ /<div class=.*?>(.*?)<\/div>/)
        {   $currentH3Anchor = "INTRODUCTION";
            $article{$currentH3Anchor}->{text} .= CleanUp("<p>$currentH3Anchor<p>\n".$1."\n");
            $article{$currentH3Anchor}->{order} = $order;
            #print $article{$currentH3Anchor}->{text}."\n\n\n";
        }
        
    }else
    {   
        while($newBodyContent =~ /<h\d class=\"h(\d)\"(>.*?)(<h\d class=\"h\d\">)/)
        {   my $tmpMatch = $2;
            my $spanClassLevel = $1;
            $newBodyContent = $3.$';        #'
            #print "---------\n".$tmpMatch."\n\n\n\n";
            if ($tmpMatch =~ /.*>(.*?)<\/h\d>/)
            {   my $anchorCandidate = $1;
                my $tmpRemainingBody = $';  #'
                if ($tmpRemainingBody =~ /<a name=\"^b/i)
                {   $tmpRemainingBody = $`; #`
                }
                if ($spanClassLevel == 3)
                {   $currentH3Anchor = $anchorCandidate;
                    my $originalH3Anchor = $anchorCandidate;
                    $currentH3Anchor =~ s/\d+|\.//g;
                    $currentH3Anchor = NormalizeName($currentH3Anchor);
                    $article{$currentH3Anchor}->{text} .= CleanUp("<p>$originalH3Anchor<p>\n".$tmpRemainingBody."\n");
                    $article{$currentH3Anchor}->{order} = $order;
                    $order++;
                }elsif ($spanClassLevel == 4)
                {   $article{$currentH3Anchor}->{text} .= CleanUp("<p>$1<p>\n".$tmpRemainingBody."\n");
                }
            }
        }
    }
    
    # Step#7: Take care the remaining reference section
    # In fact, Reference section IS NOT USED FOR SciMiner. 
    # thus, this functionality will not be implemented.

    return \%article;
}





sub ParseElseVier()
{   my $htmlArticle = shift;
    my %article = (); 
    my @sideTables = (); 
    my %sectionAnchors = ();




    # Step#1, check whether the HTML is a fulltext HTML or not
    # Fulltext ElseVier HTML seems to have 'Article outline'
    if ($htmlArticle !~ /Article Outline/)
    {   # This doesn't seem to be a real ElseVier HTMl
        exit;
    }
    my $priorArticleOutline = $`;       #`
    my $postArticleOutline = $';        #'



    # Step#2, extract the title of the paper
    if ($priorArticleOutline =~ /articleTitle\"> <p>(.*?)<\/span>/)
    {   $article{ TITLE }->{text} = CleanUp($1);
        $article{ TITLE }->{order} = 0;
    }else
    {   $article{ TITLE }->{text} = "";
        $article{ TITLE }->{order} = 0;
    }
    my $remainingPriorArticleOutline = $';


    # Step#3, extract abstract or background before #'Article outline#'
    #<p><span class="h3">
    
    if ($remainingPriorArticleOutline =~ /<p><span class=\"h3\">/)
    {   if ($' =~ /<\/span><p>/)
        {   if ($' =~ /<p>/)
            {   my $tmpAbstract = $`;
                $tmpAbstract =~ s/<i>|<\/i>//g;
                $article{ABSTRACT}->{text} = CleanUp($tmpAbstract);
            }
        }
    }else
    {   $article{ABSTRACT}->{text} = '';
    }
    $article{ABSTRACT}->{order} = 1;
    #return \%article;


    # Step#4: Find '>References</span>'
    my $bodyContent = '';
    my $referenceContent = '';
    if ($postArticleOutline =~ /<span class=\"h\d\">References<\/span><p>/)
    {   # The remaining section is for REFERENCES
        $bodyContent = $`.$&;
        $referenceContent = $';
    }elsif ($postArticleOutline =~ /<h3 class=\"h\d\">References</)   #<span class=\"h\d\">References<\/span><p>/)
    {   # The remaining section is for REFERENCES
        $bodyContent = $`.$&;
        $referenceContent = $';
    }else
    {   # If there is no 'References</span>', parsing is aborted since
        # it's also likely that the html is not a full text document.
        exit;
    }


    # Step#5: Extract figures and tables 
    # Figures and Tables start with 'blockquote'
    my $newBodyContent = $bodyContent;
    while($newBodyContent =~ /<blockquote>(.*?)<\/blockquote>/)
    {   $newBodyContent = $`.$';
        my $tmpContent = $1;
        my $tmpTableText = '';

        if ($tmpContent =~ /<p>\s*Fig/i)
        {   # This is a figure
            if ($tmpContent =~ /<\/td><\/tr><\/table>/)
            {   $article{FIGURE}->{text} .= CleanUp("\n".$'."\n");
                $article{FIGURE}->{order} = 99;
                #print $'."\n\n\n";
            }
        }elsif ($tmpContent =~ /<p>\s*Tab/i)
        {   # This is a table
            while($tmpContent =~ /<p>(.*?)(<p>)/)
            {   my $tmpMatching = $1;
                my $postContent = $';
                if ($tmpMatching !~ /<\/a>/)
                {   if ($tmpMatching =~ /<\/div>/)
                    {   $tmpTableText .= CleanUp("<p>".$`."<p>\n");
                    }else
                    {   $tmpTableText .= CleanUp("<p>".$tmpMatching."<p>\n");
                    }
                }
                $tmpContent = "<p>".$postContent;
            }
            if ( $tmpTableText ne "")
            {   $article{TABLE}->{text} .= "\n".$tmpTableText."\n";
                $article{TABLE}->{order} = 99;
                #print $article{TABLE}->{text}."\n\n";
            }
        }
    }


    
    # Step#6: Handle remaining main body; methods, results, and discussion
    my $currentH3Anchor = '';
    my $order = 2;
    
    #  If there is no appropriate H3 level section, check only if there is probable
    #  candidate section, and put it as OTHER section.
    if ($newBodyContent !~ /<span class=\"h(\d+)\"(>.*?)(<span class=\"h\d+\">)/)
    {   #  There is no appropriate section found. 
        #  1) there is really nothing
        #  2) there is something without section anchor
        #  print "\n\n\n\n\n\n".$newBodyContent."\n\n\n\n\n";
        if ($newBodyContent =~ /<div class=.*?>(.*?)<\/div>/)
        {   $currentH3Anchor = "INTRODUCTION";
            $article{$currentH3Anchor}->{text} .= CleanUp("<p>$currentH3Anchor<p>\n".$1."\n");
            $article{$currentH3Anchor}->{order} = $order;
            #print $article{$currentH3Anchor}->{text}."\n\n\n";
        }
        
    }else
    {   while($newBodyContent =~ /<span class=\"h(\d+)\"(>.*?)(<span class=\"h\d+\">)/)
        {   my $tmpMatch = $2;
            my $spanClassLevel = $1;
            $newBodyContent = $3.$';        #'
            #print "---------\n".$tmpMatch."\n\n\n\n";
            if ($tmpMatch =~ /.*>(.*?)<\/span>/)
            {   my $anchorCandidate = $1;
                my $tmpRemainingBody = $';  #'
                if ($tmpRemainingBody =~ /<a name=\"^b/i)
                {   $tmpRemainingBody = $`; #`
                }
                if ($spanClassLevel == 3)
                {   $currentH3Anchor = $anchorCandidate;
                    my $originalH3Anchor = $anchorCandidate;
                    $currentH3Anchor =~ s/\d+|\.//g;
                    $currentH3Anchor = NormalizeName($currentH3Anchor);
                    $article{$currentH3Anchor}->{text} .= CleanUp("<p>$originalH3Anchor<p>\n".$tmpRemainingBody."\n");
                    $article{$currentH3Anchor}->{order} = $order;
                    $order++;
                }elsif ($spanClassLevel == 4)
                {   $article{$currentH3Anchor}->{text} .= CleanUp("<p>$1<p>\n".$tmpRemainingBody."\n");
                }
            }
        }
    }
    
    # Step#7: Take care the remaining reference section
    # In fact, Reference section IS NOT USED FOR SciMiner. 
    # thus, this functionality will not be implemented.

    return \%article;
}


# sub CleanUp
# This subroutine cleans the HTML text and convert it to a regular text file
sub CleanUp()
{   my $text = shift; 
    
    $text =~ s///gi;

    $text =~ s/<h(\d)>(.*?)<\/h(\d)>/<p>$2<\/p>/msgi;
    $text =~ s/<\/*(br|p)>/\n/gi;
    $text =~ s/<SUP>.*?<\/SUP>/ /ig;
    $text =~ s/<SUB>.*?<\/SUB>/ /ig;
    $text =~ s/<I>.*?<\/I>/ /ig;

    $text =~ s/<img.*?alt=\"[ \{]*(~|alpha|beta|gamma|delta|epsilon|kappa|phi|psi|zeta)[ \}]*.*?>/ $1/gi;

    $text =~ s/<\/*(.*?)>//g;
    $text =~ s/&/&amp;/g;

    $text =~ s/&amp;nbsp;/ /gi;
    $text =~ s/&amp;lt;/&lt;/gi;
    $text =~ s/&amp;gt;/&gt;/gi;

    $text =~ s/&amp;#176;/degree/gi;
    $text =~ s/&amp;#160;/ /gi;
    $text =~ s/&amp;#150;/-/gi;
    $text =~ s/&amp;#146;/'/gi;
    $text =~ s/&amp;#145;/'/gi;
    $text =~ s/&amp;#181;/micro/gi;


    my @paragraphs = split( /\n/, $text );
    $text = "";
    foreach my $paragraph (@paragraphs)
    {
        $text .= "<p>$paragraph<\/p>\n";
    }
    $text =~ s/\s+/ /g;
    $text =~ s/<p>\s*<\/p>//g;

    return $text;
}


sub NormalizeName()
{
	my ($sectionName, $order) = @_;

	my $knownName = 0;

 	if( $sectionName =~ /abstract/i ) 		            { $sectionName = "ABSTRACT"; $knownName = 1; }
	if( $sectionName =~ /material|method|procedure/i ) 	{ $sectionName = "METHODS"; $knownName = 1; }
	if( $sectionName =~ /reference/i ) 		            { $sectionName = "REFERENCES"; $knownName = 1; }
	if( $sectionName =~ /conclusion/i ) 		        { $sectionName = "CONCLUSION"; $knownName = 1; }
	if( $sectionName =~ /discussion/i ) 		        { $sectionName = "DISCUSSION"; $knownName = 1; }
	if( $sectionName =~ /result/i ) 		            { $sectionName = "RESULTS"; $knownName = 1; }
	if( $sectionName =~ /introduction/i ) 	            { $sectionName = "INTRODUCTION"; $knownName = 1; }
	if( $sectionName =~ /outline/i ) 		            { $sectionName = "OUTLINE"; $knownName = 1; }
	if( $sectionName =~ /<p>/i && $order == 0) 	        { $sectionName = "TITLE"; $knownName = 1; }

	if( ! $knownName )
	{
		#print STDERR "Error with Section Name! Name seen as <$sectionName>...";
		if( $sectionName=~ /(\w+)/ )
		{ 
			#print STDERR "Setting to <$1>\n"; 
			$sectionName = uc($1); 
		}
		else
		{
			#print STDERR "Setting to <UNKNOWN>\n"; 
			$sectionName = "UNKNOWN\n";
		}
	}
        
    #print "Anchor was <$sectionName>\n";
    
    return $sectionName;
}


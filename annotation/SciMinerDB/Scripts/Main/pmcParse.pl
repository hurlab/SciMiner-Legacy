#!/usr/bin/perl -w

#
# pmcParse.pl
#
# Multi-purpose parser for HTML->XML for HighWire and PMC
#
# Usage: ./pmcParse.pl <HTML> > XMLFILE
#
# Prints standardized XML format from publisher's HTML full-text article if found
#  also supports older-style HighWire with ParseOldHighWire();
#
# Version 1.1: 1) Removing the following line from CleanUp() will cause problem.
#                    $text =~ s/&/&amp;/g;
# Version 2.0: 1)  ParseHighWireLastTry was added
#              2) html text is passed to sub-routins as reference  

local $|;
no warnings 'prototype';

open( HTML, $ARGV[0] ) || print "!ERROR! Can't open HTML file for input! File was: $ARGV[0]\n";

my @HTMLfile = <HTML>;
my ($PMID) = $ARGV[0] =~ m|(\d+).htm|;
# Also try matching .xml extension for JATS XML files (added 2026-03)
if (!defined $PMID || $PMID eq '')
{   ($PMID) = $ARGV[0] =~ m|(\d+)\.xml|;
}
if (!defined $PMID || $PMID eq '')
{   ($PMID) = $ARGV[0] =~ m|PMC(\d+)|;
}
foreach my $line (@HTMLfile){ chomp $line; }
my $htmlArticle = join(' ', @HTMLfile);
my %article = ();


# ---- JATS XML Detection (added 2026-03) ----
# Modern PMC articles use JATS XML format. Detect and parse first.
if ($htmlArticle =~ /<article[\s>]/ &&
    ($htmlArticle =~ /<body[\s>]/ || $htmlArticle =~ /<front[\s>]/))
{   %article = %{ ParseJATS_XML( \$htmlArticle ) };
    if (scalar(keys %article) >= 1)
    {   # JATS parsing successful - skip HighWire parsers
        goto OUTPUT_XML;
    }
}
# ---- End JATS XML Detection ----

# Try parsing with HighWire standard parser
%article = %{ ParseHighWire( \$htmlArticle ) };

# Otherwise use the old-format HighWire parser
if( scalar( keys(%article) ) < 1 )
{	
    %article = %{ ParseOldHighWire( \$htmlArticle ) };
}else
{   # print STDERR "Parsing by ParseHighWire was successful\n";
}

# If we've still only got one key...there was an error in the parse...
if( scalar( keys(%article) ) < 1 )
{   
    %article = %{ ParseHighWireLastTry( \$htmlArticle ) };
}else
{   # print STDERR "Parsing by ParseOldHighWire was successfull\n";
}

# Label for JATS XML early exit (added 2026-03)
OUTPUT_XML:

# Print out the resulting XML file
print "<DOC>\n<PMID>$PMID<\/PMID>\n";

my $outputContent = '';
# Check whether this is required. #
foreach my $section( sort( { $article{$a}->{order} <=> $article{$b}->{order} } keys( %article) ) )
{   my $modified = $article{$section}->{text};
    if (defined $modified)
    {
        $modified =~ s/ \< / \&lt; /g;
    	$modified =~ s/ \& / \&amp\; /g;
    	$modified =~ s/\&hyp\;/\'/g;
    	$outputContent .= "<$section>\n$modified<\/$section>\n\n";
    }
#	if ($modified =~ /\</) 
#	{   
#		$modified =~ s/([p|P])\<([\.|\d])/$1\&lt\;$2/g;
#		$modified =~ s/([^pP])\<(\/?[^pP])/$1\&lt\;$2/g;
#		
#		#if ($AbstractContent =~ /p\<[\.|\d]/) 
#		#{   #p<.05 or p<0.05, which are p-values. This is unmatched < so needs to be replaced by '&nt;'
#		#	$AbstractContent =~ s/p\<[\.|\d]/p\&lt\;/g;
#		#}
#	}
}


$outputContent =~ s/<p><\/p>//g;
print $outputContent;
print "</DOC>";
exit;




sub ParseHighWireLastTry
{   #  This is to be used after both new and old ParseHighWire failed.
    my $htmlArticleRef  = shift;
    
    my %article         = (); 
    my @sideTables      = (); 
    my $htmlContent     = '';
    my $secAnchor       = '';

    print "HigiWireLast\n";
    #  Check for error
	if (($$htmlArticleRef =~ /<p class="error">/i) || ($$htmlArticleRef =~ /No abstract is available/i))
	{   return (\%article);
	}
    
    ##  Remove anything before the possible abstract
    #if ($htmlContent =~ /<A NAME="(Abstract|ABS)">/i)
    #{   $htmlContent = $&.$';
    #}
    #if (($htmlContent =~ /<A NAME="References">/i) || ( $htmlContent =~ /<A NAME="BIBL">/i))
    #{   $htmlContent = $`;
    #}
    
    
   
    # Throw away footnotes for now!
    $$htmlArticleRef =~ s/<a name=\"R(FN\d+)\">.*?<a href=\"#FN\d+\">//msgi;
    
    # Throw away table parts
    $$htmlArticleRef =~ s/<table[^>]+>.*?<\/table>//msgi;
    
    if ($$htmlArticleRef =~ /<BODY.*<\/BODY>/i)
    {   $htmlContent    = $&;
    }else
    {   $htmlContent    = $$htmlArticleRef;
    }
   
    #  Check for references and throw them away
    if (($htmlContent =~ /<A NAME="R1">/i) || ($htmlContent =~ /References<.*?$/i) || ($htmlContent =~ /ACKNOWLEDGMENTS<.*?$/i) || ($htmlContent =~ /<A NAME="BIBL">/))
    {   $htmlContent    = $`;
    }
    
  
    #  Change <p> tag
    $htmlContent        =~ s/<p>/<P>/g;
    $htmlContent        =~ s/<\/p>/<\/P>/g;
    $htmlContent        =~ s/<\\p>/<\\P>/g;
    
    ##  Check for mailto:  ==> 02/22/2008 This turns out to be not working as expected
    #if ($htmlContent    =~ /mailto:.*?<\\?\/a>/i)
    #{   my @docSplit    = ();
    #    if (length($`) > length($'))
    #    {   @docSplit   = split (/<P>/, $`);
    #    }else
    #    {   @docSplit    = split (/<P>/, $');
    #    }
    #    
    #    foreach my $line (@docSplit)
    #    {   $article{ UNKNOWN }->{text} .= CleanUp($line);
    #        $article{ UNKNOWN }->{order} = 97;
    #    }
    #}else
    #{   my @docSplit    = split (/<P>/, $htmlContent);
    #    foreach my $line (@docSplit)
    #    {   $article{ UNKNOWN }->{text} .= CleanUp($line);
    #        $article{ UNKNOWN }->{order} = 97;
    #    }
    #}
    
    
    my @docSplit        = split (/<P>/, $htmlContent);
    foreach my $line (@docSplit)
    {   if ($line !~ /mailto:/)
        {   $article{ UNKNOWN }->{text} .= CleanUp($line);
            $article{ UNKNOWN }->{order} = 97;
        }
    }
    
    return (\%article);
}









sub ParseHighWire()
{   my $htmlArticleRef = shift;
    my %article = (); 
    my @sideTables = (); 
    my $secAnchor       = '';
    
    #  Check for error
	if (($$htmlArticleRef =~ /<p class="error">/i) || ($$htmlArticleRef =~ /No abstract is available/i))
	{   return (\%article);
	}
	
	my $htmlContent = ${$htmlArticleRef};
	
	#  Remove anything before the possible abstract
    if ($htmlContent =~ /<A NAME="(Abstract|ABS)">/i)
    {   $htmlContent = $&.$';
    }
    if (($htmlContent =~ /<A NAME="References">/i) || ( $htmlContent =~ /<A NAME="BIBL">/i))
    {   $htmlContent = $`;
    }
    
    # Throw away footnotes for now!
    $htmlContent =~ s/<a name=\"RFN\d+\">(.*)?<a href="#FN\d+">//msgi;
    #$htmlContent =~ s/<a name=\"REF\d+\">.*?<a href=\"#FN\d+\">//msgi;

    #
    # First...we go through and find the left-aligned tables...to get the meaningful section anchors
    #
    
    my %sectionAnchors = ();
    while( $htmlContent =~ /<table align=right.*?>(.*?)<\/table>/msgi ) 
    {   
        my $sideTable = $1;
        while( $sideTable =~ /<a +href=\"#(\w+?)\">(<img.*?arrow.gif\">)((\w|\s)+).*?<\/a>/msgi )  
        {   
            my $sectionAnchor= $1;
            my $sectionName= $3;
            $sectionAnchors{$sectionAnchor} = $sectionName;
        }
    }

    # If there are less than 4 section anchors, forget about this side-section
    my $countKey    = scalar (keys %sectionAnchors);
    if ($countKey < 4)
    {   %sectionAnchors  = ();
    }
    
    #
    # Figures and tables get special treatment...they also go at the end (order=99)
    #

    while( $htmlContent =~ /<center>.*?<table(.*?)\[in a new window\].*?<td align=left valign=top>(.*?)<\/td><\/tr><\/table>/msgi )
    {   
        my $figKey = $tableAnchor;
        my $figText= $2;

        $figText = CleanUp( $figText );

        if( $figText =~ /^<p>\s+Fig/i )
        {   
            $figKey = "FIGURES";
        }
        elsif( $figText =~ /^<p>\s+Tab/i )
        {   
            $figKey = "TABLES";
        }
        else
        {   $figKey = "UNKNOWN";
        }
        
        $article{ $figKey }->{text} .= "\n$figText\n";
        $article{ $figKey }->{order} = 99;
        # print "FOUND \n***$figKey *******\n$figText\n****\n\n";
    }


    # Get the References, typically anchors beginning with a B or a R
    while( $htmlContent =~ /<a name=\"([B|R]\w+)\">(.*?)(?=<a name)/msgi )
    {   
        my $tableAnchor = $1;
        my $refText = $2;

        $refText = CleanUp( $refText );

        $article{ REFERENCES }->{text} .= "\n$refText\n\n";
        $article{ REFERENCES }->{order} = 90;
    }


    # Strip out tables (mostly figures, etc) which should have been parsed out already
    $htmlContent =~ s/<table[^>]+>.*?<\/table>//msgi;

    # Anchor-wise parse through the document...from one anchor to the next, keeping
    # track of the $CurrentSection, since not all anchors are created equal (e.g. only the
    # ones from the sidebars above are the meaningful ones...when we pass one, we update
    # $CurrentSection and the $order

    my $order = 0;
    my $CurrentSection = "";

    
    # Split and conquer
    my @docSplit  = split (/<A NAME=/, $htmlContent);
    foreach my $line (@docSplit)
    {   if ($line =~ /^"(.*?)">/)
        {   my $tableAnchor = $1;
            my $content     = $';
            if (defined $sectionAnchors{$tableAnchor} )
            {   #  There is a matching section anchor for this one
                $secAnchor  = $sectionAnchors{$tableAnchor};
                $article{$secAnchor}->{order} = $order++;
            }else
            {   #  If not defined, use any pre-existing secAnchor
                my $tmpName = NormalizeName($tableAnchor);
                if ($tmpName eq "UNKNOWN")
                {   # Proceed with the anchor
                    $article{UNKNOWN}->{order} = 97;
                }else
                {   $secAnchor  = $tmpName;
                }    
            }
            
            if ($secAnchor eq "")
            {   $article{$secAnchor}->{text} .= CleanUp($content);
            }else
            {   $article{UNKNOWN}->{text} .= CleanUp($content);
            }
        }else
        {   # print "!!! $line\n\n";
        }
    }

    #  Remove the reference section
    $article{REFERENCES}->{text} = '';
    $article{REFERENCES}->{order} = 89;
    
    
    return \%article;
}




	
sub ParseOldHighWire()
{   my $htmlArticleRef = shift;
    my %article = (); 
    my @sideTables = (); 

    print "HigiWireOld\n";
    #  Check for error
	if (($$htmlArticleRef =~ /<p class="error">/i) || ($$htmlArticleRef =~ /No abstract is available/i))
	{   return (\%article);
	}
	
	my $htmlContent = ${$htmlArticleRef};
	
	#  Remove anything before the possible abstract
    if ($htmlContent =~ /<A NAME="(Abstract|ABS)">/i)
    {   $htmlContent = $&.$';
    }
    if (($htmlContent =~ /<A NAME="References">/i) || ( $htmlContent =~ /<A NAME="BIBL">/i))
    {   $htmlContent = $`;
    }
    
    #
    # First...we go through and find the left-aligned tables...to get the meaningful section anchors
    #
    my %sectionAnchors = ();

    # Throw away footnotes for now!
    $htmlContent =~ s/<a name=\"R(FN\d+)\">.*?<a href=\"#FN\d+\">//msgi;


    if( $htmlContent =~ /<!--\s*#+\s+ARTICLE NAV\s+#+\s*-->.*?<dl>(.*?)<\/dl>/msgi ) 
    {   
        my $navTable = $1;

        #print $navTable;
        while( $navTable=~ /<a href=\"?#(\w+?)\"?>(<img.*?.gif\">)((\w|\s)+).*?<\/a>/msgi )  
        {   my $sectionAnchor= $1;
            my $sectionName= $3;

            #print "ADDING SECTION: $sectionAnchor -- $sectionName\n";
            $sectionAnchors{$sectionAnchor} = $sectionName;
        }
    }

    #foreach my $anchor( keys(%sectionAnchors) )
    #{
    #   print "\nKEY $anchor Name: $sectionAnchors{$anchor}\n";
    #}

    #
    # Figures and tables get special treatment...they also go at the end (order=99)
    #

    while( $htmlContent =~ /<strong>(?>.*?)(fig.*?)<\/strong>(.*?)<hr>/msgi )
    {   
        my $figKey = $tableAnchor;
        my $figText= $2;

        $figText = CleanUp( $figText );

        if( $figText =~ /^<p>\s+Fig/i )
        {
            $figKey = "FIGURES";
        }
        elsif( $figText =~ /^<p>\s+Tab/i )
        {
            $figKey = "TABLES";
        }
        else
        {
            #print STDERR "\n\nFIGURE TEXT WAS!!!!!!!!!!!! <$figText>\n\n";
            $figKey = "ADDITIONALTEXT";
        }


        $article{ $figKey }->{text} .= "\n$figText\n";
        $article{ $figKey }->{order} = 99;
        # print "FOUND \n***$figKey *******\n$figText\n****\n\n";
    }

    # Get the References, typically anchors beginning with a B

    while( $htmlContent =~ /<a name=\"(B\w+)\">(.*?)(?=<a name)/msgi )
    {   
        my $tableAnchor = $1;
        my $refText = $2;

        $refText = CleanUp( $refText );

        $article{ REFERENCES }->{text} .= "\n$refText\n\n";
        $article{ REFERENCES }->{order} = 90;
    }


    # Strip out tables (mostly figures, etc) which should have been parsed out already

    $htmlContent =~ s/<table[^>]+>.*?<\/table>//msgi;

    # Anchor-wise parse through the document...from one anchor to the next, keeping
    # track of the $CurrentSection, since not all anchors are created equal (e.g. only the
    # ones from the sidebars above are the meaningful ones...when we pass one, we update
    # $CurrentSection and the $order

    my $order = 0;
    my $CurrentSection = "";

    while( $htmlContent =~ /<a name\s*=\s*\"(\w+)\">(.*?)(?=<a name)/msgi )
    {   
        my $tableAnchor = $1;
        my $tableContent = $2; 

        #Check to see if we've triggered a major section change (these are from the side bar)
        if( exists( $sectionAnchors{$tableAnchor} ) )
        {
            $CurrentSection = NormalizeName( $sectionAnchors{$tableAnchor}, $order );
            $article{$CurrentSection}->{order} = $order++;
            #	print "$CurrentSection GOT AN ORDER OF $article{$CurrentSection}->{order}\n";
        }

        #            print "\n\n-------- $tableAnchor - MajorSection $CurrentSection ------\n\n";

        #Save only the paragraphs

        while( ($tableContent =~ /<(p|br).*?>(.*?)(?=(<\/p>|$))/msgi ) && $CurrentSection)
        {   
            my $secText = $2;

            $secText = CleanUp( $secText );
            $article{$CurrentSection}->{text} .= "$secText\n";
        }
        # print "\n##########\n$article{$CurrentSection}->{text}\n########\n\n";
    }

    $article{REFERENCES}->{text} = '';
    return \%article;
}









# sub CleanUp
# This subroutine cleans the HTML text and convert it to a regular text file
sub CleanUp()
{   my $text = shift; 
    
    $text =~ s/<h(\d)>(.*?)<\/h(\d)>/<p>$2<\/p>/msgi;
    $text =~ s/<\/*(br|p)>/\n/gi;
    $text =~ s/<SUP>.*?<\/SUP>/ /g;
    $text =~ s/<img.*?alt=\"[ \{]*(~|alpha|beta|gamma|delta|epsilon|kappa|phi|psi|zeta)[ \}]*.*?>/ $1/gi;

    $text =~ s/<\/*(.*?)>/ /g;
    $text =~ s/&/&amp;/g;

    $text =~ s/&amp;nbsp;/ /gi;
    $text =~ s/&amp;lt;/&lt;/gi;
    $text =~ s/&amp;gt;/&gt;/gi;

    $text =~ s/&amp;#176;/degree/gi;
    $text =~ s/&amp;#160;/ /gi;
    $text =~ s/&amp;#150;/-/gi;
    $text =~ s/&amp;#8211;/-/gi;
    $text =~ s/&amp;#146;/'/gi;
    $text =~ s/&amp;#145;/'/gi;
    $text =~ s/&amp;#181;/micro/gi;
    
    # alpha
    $text =~ s/&amp;#x03B1;/A/gi;
    $text =~ s/&amp;#945;/A/gi;    
    
    # beta
    $text =~ s/&amp;#x03B2;/B/gi;
    $text =~ s/&amp;#946;/B/gi;    
    
    # gamma
    $text =~ s/&amp;#x03B3;/G/gi;
    $text =~ s/&amp;#947;/G/gi;    

    # Kappa
    $text =~ s/&amp;#954;/kappa/gi;
    $text =~ s/&amp;#x03Ba;/kappa/gi;
    
    my @paragraphs = split( /\n/, $text );
    $text = "";
    foreach my $paragraph (@paragraphs)
    {
        $text .= "<p>$paragraph<\/p>\n";
    }
    $text =~ s/\s+/ /g;
    $text =~ s/<p>\s+<\/p>//g;

    return $text;
}



sub NormalizeName()
{   my $sectionName = shift;
    my $order       = shift;

	my $knownName = 0;

 	if( $sectionName =~ /abstract/i ) 		            	{ $sectionName = "ABSTRACT"; $knownName = 1; }
	elsif( $sectionName =~ /material|method|implementation|procedure/i ) 	
															{ $sectionName = "METHODS"; $knownName = 1; }
	elsif( $sectionName =~ /reference/i ) 		            { $sectionName = "REFERENCES"; $knownName = 1; }
	elsif( $sectionName =~ /conclusion/i ) 		        	{ $sectionName = "CONCLUSION"; $knownName = 1; }
	elsif( $sectionName =~ /discussion/i ) 		        	{ $sectionName = "DISCUSSION"; $knownName = 1; }
	elsif( $sectionName =~ /result/i ) 		            	{ $sectionName = "RESULTS"; $knownName = 1; }
	elsif( $sectionName =~ /background/i ) 	            	{ $sectionName = "INTRODUCTION"; $knownName = 1; }
	elsif( $sectionName =~ /introduction/i ) 	            { $sectionName = "INTRODUCTION"; $knownName = 1; }
	elsif( $sectionName =~ /outline/i ) 		            { $sectionName = "OUTLINE"; $knownName = 1; }
	elsif( $sectionName =~ /author/i ) 		            	{ $sectionName = "AUTHORS"; $knownName = 1; }
	elsif( $sectionName =~ /acknowledgement/i ) 		    { $sectionName = "ACKNOWLEDGMENTS"; $knownName = 1; }
	elsif( $sectionName =~ /<p>/i && $order == 0) 	        { $sectionName = "TITLE"; $knownName = 1; }
	else
	{   $sectionName = "UNKNOWN";
	}
    return $sectionName;
}


#sub NormalizeName()
#{
#	my ($sectionName, $order) = @_;
#
#	my $knownName = 0;
#
# 	if( $sectionName =~ /abstract/i ) 		            { $sectionName = "ABSTRACT"; $knownName = 1; }
#	if( $sectionName =~ /material|method|procedure/i ) 	{ $sectionName = "METHODS"; $knownName = 1; }
#	if( $sectionName =~ /reference/i ) 		            { $sectionName = "REFERENCES"; $knownName = 1; }
#	if( $sectionName =~ /conclusion/i ) 		        { $sectionName = "CONCLUSION"; $knownName = 1; }
#	if( $sectionName =~ /discussion/i ) 		        { $sectionName = "DISCUSSION"; $knownName = 1; }
#	if( $sectionName =~ /result/i ) 		            { $sectionName = "RESULTS"; $knownName = 1; }
#	if( $sectionName =~ /introduction/i ) 	            { $sectionName = "INTRODUCTION"; $knownName = 1; }
#	if( $sectionName =~ /outline/i ) 		            { $sectionName = "OUTLINE"; $knownName = 1; }
#	if( $sectionName =~ /ACKNOWLEDGEMENT/i ) 		    { $sectionName = "ACKNOWLEDGEMENT"; $knownName = 1; }
#	if( $sectionName =~ /<p>/i && $order == 0) 	        { $sectionName = "TITLE"; $knownName = 1; }
#
#	if( ! $knownName )
#	{   $sectionName = "UNKNOWN";
#		
#		##print STDERR "Error with Section Name! Name seen as <$sectionName>...";
#		#if( $sectionName=~ /(\w+)/ )
#		#{ 
#		#    print "Unknown section name\t$sectionName";
#	#		#print STDERR "Setting to <$1>\n"; 
#	#		$sectionName = uc($1); 
#	#	}
#	#	else
#	#	{
#	#		#print STDERR "Setting to <UNKNOWN>\n"; 
#	#		$sectionName = "UNKNOWN\n";
#	#	}
#	}
#       
#    #print "Anchor was <$sectionName>\n";
#    
#    return $sectionName;
#}


# =============================================================================
# ParseJATS_XML()
#
# Parses modern PMC articles in JATS (Journal Article Tag Suite) XML format.
# This is the standard format for PubMed Central Open Access articles.
#
# Input:  Reference to string containing JATS XML content
# Output: Reference to %article hash with section names as keys,
#         each containing {text} and {order} fields.
#
# Added 2026-03 to handle modern PMC JATS XML format.
# =============================================================================
sub ParseJATS_XML
{   my $xmlRef = shift;
    my %article = ();
    my $order   = 0;
    my $xml     = $$xmlRef;

    # ---- Extract Title ----
    if ($xml =~ /<article-title>(.*?)<\/article-title>/si)
    {   my $title = $1;
        $title = _jats_strip_markup($title);
        $title =~ s/\s+/ /g;
        $title =~ s/^\s+|\s+$//g;
        if ($title ne '')
        {   $article{TITLE}->{text}  = &CleanUp($title);
            $article{TITLE}->{order} = $order++;
        }
    }

    # ---- Extract Abstract ----
    if ($xml =~ /<abstract[^>]*>(.*?)<\/abstract>/si)
    {   my $absContent = $1;
        my $absText = '';

        # Structured abstract with subsections
        if ($absContent =~ /<sec/)
        {   while ($absContent =~ /<sec[^>]*>(.*?)<\/sec>/sig)
            {   my $absSec = $1;
                my $subTitle = '';
                if ($absSec =~ /<title>(.*?)<\/title>/si)
                {   $subTitle = _jats_strip_markup($1);
                    $subTitle =~ s/^\s+|\s+$//g;
                }
                while ($absSec =~ /<p[^>]*>(.*?)<\/p>/sig)
                {   my $pText = _jats_strip_markup($1);
                    $pText =~ s/\s+/ /g;
                    $pText =~ s/^\s+|\s+$//g;
                    if ($subTitle ne '')
                    {   $absText .= "$subTitle: $pText\n";
                    }else
                    {   $absText .= "$pText\n";
                    }
                }
            }
        }else
        {   # Unstructured abstract
            while ($absContent =~ /<p[^>]*>(.*?)<\/p>/sig)
            {   my $pText = _jats_strip_markup($1);
                $pText =~ s/\s+/ /g;
                $pText =~ s/^\s+|\s+$//g;
                $absText .= "$pText\n";
            }
            # If no <p> tags
            if ($absText eq '' && $absContent =~ /\S/)
            {   $absText = _jats_strip_markup($absContent);
                $absText =~ s/\s+/ /g;
                $absText =~ s/^\s+|\s+$//g;
            }
        }

        if ($absText ne '')
        {   $article{ABSTRACT}->{text}  = &CleanUp($absText);
            $article{ABSTRACT}->{order} = $order++;
        }
    }

    # ---- Extract Body Sections ----
    if ($xml =~ /<body[^>]*>(.*)<\/body>/si)
    {   my $bodyContent = $1;

        # Process top-level <sec> elements
        while ($bodyContent =~ /<sec[^>]*?>(.*?)<\/sec>\s*(?=<sec[\s>]|$)/sig)
        {   my $secContent = $1;
            my $secTitle = 'UNKNOWN';

            if ($secContent =~ /<title>(.*?)<\/title>/si)
            {   $secTitle = _jats_strip_markup($1);
                $secTitle =~ s/^\s+|\s+$//g;
            }

            my $normalizedName = &NormalizeName($secTitle, $order);

            # Skip references
            next if ($normalizedName eq 'REFERENCES');
            next if ($secTitle =~ /supplement/i);
            next if ($secTitle =~ /supporting\s+information/i);

            # Extract text from paragraphs (including nested subsections)
            my $secText = '';
            # Remove figure/table elements (processed separately)
            $secContent =~ s/<fig[^>]*>.*?<\/fig>//sig;
            $secContent =~ s/<table-wrap[^>]*>.*?<\/table-wrap>//sig;

            while ($secContent =~ /<p[^>]*>(.*?)<\/p>/sig)
            {   my $pText = _jats_strip_markup($1);
                $pText =~ s/\s+/ /g;
                $pText =~ s/^\s+|\s+$//g;
                $secText .= "$pText\n" if $pText ne '';
            }

            if ($secText ne '')
            {   $article{$normalizedName}->{text}  .= &CleanUp($secText);
                $article{$normalizedName}->{order} = $order
                    unless defined $article{$normalizedName}->{order};
                $order++;
            }
        }

        # If no <sec> found, extract paragraphs directly
        if ($order < 2)
        {   my $bodyText = '';
            while ($bodyContent =~ /<p[^>]*>(.*?)<\/p>/sig)
            {   my $pText = _jats_strip_markup($1);
                $pText =~ s/\s+/ /g;
                $pText =~ s/^\s+|\s+$//g;
                $bodyText .= "$pText\n" if $pText ne '';
            }
            if ($bodyText ne '')
            {   $article{UNKNOWN}->{text}  = &CleanUp($bodyText);
                $article{UNKNOWN}->{order} = $order++;
            }
        }
    }

    # ---- Figure captions ----
    my $figText = '';
    while ($xml =~ /<fig[^>]*>(.*?)<\/fig>/sig)
    {   if ($1 =~ /<caption>(.*?)<\/caption>/si)
        {   my $caption = $1;
            while ($caption =~ /<p[^>]*>(.*?)<\/p>/sig)
            {   my $pText = _jats_strip_markup($1);
                $pText =~ s/\s+/ /g;
                $pText =~ s/^\s+|\s+$//g;
                $figText .= "$pText\n" if $pText ne '';
            }
        }
    }
    if ($figText ne '')
    {   $article{FIGURES}->{text}  = &CleanUp($figText);
        $article{FIGURES}->{order} = 98;
    }

    # ---- Table captions ----
    my $tableText = '';
    while ($xml =~ /<table-wrap[^>]*>(.*?)<\/table-wrap>/sig)
    {   if ($1 =~ /<caption>(.*?)<\/caption>/si)
        {   my $caption = $1;
            while ($caption =~ /<p[^>]*>(.*?)<\/p>/sig)
            {   my $pText = _jats_strip_markup($1);
                $pText =~ s/\s+/ /g;
                $pText =~ s/^\s+|\s+$//g;
                $tableText .= "$pText\n" if $pText ne '';
            }
        }
    }
    if ($tableText ne '')
    {   $article{TABLES}->{text}  = &CleanUp($tableText);
        $article{TABLES}->{order} = 99;
    }

    return \%article;
}


# =============================================================================
# _jats_strip_markup($text)
#
# Strips JATS XML inline markup while preserving text content.
# Removes bibliography citation references.
#
# Added 2026-03 for JATS XML parsing support.
# =============================================================================
sub _jats_strip_markup
{   my $text = shift;
    return '' unless defined $text;

    # Remove bibliography citations
    $text =~ s/<xref[^>]*ref-type\s*=\s*"bibr"[^>]*>.*?<\/xref>//sig;
    # Remove footnote references
    $text =~ s/<xref[^>]*ref-type\s*=\s*"fn"[^>]*>.*?<\/xref>//sig;
    # Keep text of other xref types
    $text =~ s/<xref[^>]*>(.*?)<\/xref>/$1/sig;

    # Preserve text in formatting elements
    $text =~ s/<(?:italic|bold|underline|monospace|sc|named-content|styled-content)[^>]*>(.*?)<\/(?:italic|bold|underline|monospace|sc|named-content|styled-content)>/$1/sig;

    # Superscript/subscript - keep text
    $text =~ s/<sup>(.*?)<\/sup>/$1/sig;
    $text =~ s/<sub>(.*?)<\/sub>/$1/sig;

    # External links - keep display text
    $text =~ s/<ext-link[^>]*>(.*?)<\/ext-link>/$1/sig;
    $text =~ s/<email>(.*?)<\/email>/$1/sig;

    # Formulas
    $text =~ s/<inline-formula>.*?<\/inline-formula>/ [formula] /sig;
    $text =~ s/<disp-formula[^>]*>.*?<\/disp-formula>/ [formula] /sig;

    # Remove remaining XML tags
    $text =~ s/<[^>]+>//g;

    # Decode XML entities
    $text =~ s/&amp;/&/g;
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&quot;/"/g;
    $text =~ s/&apos;/'/g;

    return $text;
}


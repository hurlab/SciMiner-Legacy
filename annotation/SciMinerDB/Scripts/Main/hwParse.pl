#!/usr/bin/perl -w

#
# hwParse.pl					version 3.0
#
# Multi-purpose parser for HTML->XML for HighWire
#
# Usage: ./hwParse.pl <HTML> > XMLFILE
#
# Prints standardized XML format from publisher's HTML full-text article if found
#  also supports older-style HighWire with ParseOldHighWire();
#
# Version 1.1: 	1) Removing the following line from CleanUp() will cause problem.
#                    $text =~ s/&/&amp;/g;
# Version 2.0: 	1)  ParseHighWireLastTry was added
#              	2) html text is passed to sub-routins as reference  
# Version 3.0  	1) Script name has been changed to hwParse.pl from pmcParse.pl
#				2) Types of different highwire compatible documents are determined


local $|;
no warnings 'prototype';
use strict;


open( HTML, $ARGV[0] ) || print "!ERROR! Can't open HTML file for input! File was: $ARGV[0]\n";

my @HTMLfile = <HTML>;
my ($PMID) = $ARGV[0] =~ m|(\d+).htm|;
foreach my $line (@HTMLfile){ chomp $line; }
my $htmlArticle = join(' ', @HTMLfile);
my %article = ();


#  Check for error - or no abstract note -> not a full text
if (($htmlArticle =~ /<p class="error">/i) || ($htmlArticle =~ /No abstract is available/i))
{   print_out_article_parsing_result(\%article);
	exit;
}



#  Check for 'Article Navigator'              #  <!-- #### ARTICLE NAV  #### -->
if ($htmlArticle	=~ /<!-- #### ARTICLE NAV  #### -->/)
{   %article = %{ ParseHighWireWithArticleNav( \$htmlArticle ) };
	if( scalar( keys(%article) ) >= 1 )
	{	print_out_article_parsing_result(\%article);
		exit;
	}
}



#  Check for side-anchor (this can be used as tablesection anchor)
elsif (($htmlArticle =~ /<table align=right.*?>(.*?)<\/table>/i) && ($1 =~ /<a +href=\"#(\w+?)\">(<img.*?arrow.gif\">)((\w|\s)+).*?<\/a>/i))
{	%article = %{ ParseHighWireWithSideAnchors( \$htmlArticle ) };
	if( scalar( keys(%article) ) >= 1 )
	{	print_out_article_parsing_result(\%article);
		exit;
	}
}

elsif ($htmlArticle =~ /<tr><td class="content_box_title_highlight" colspan="2">This Article<\/td><\/tr>.*?<\/table>.*?<\/table>/)
{	my $tmpArticle	= $';   
	%article = %{ ParseHighWireWithBigThisArticleBox( \$tmpArticle ) };
	if( scalar( keys(%article) ) >= 1 )
	{	print_out_article_parsing_result(\%article);
		exit;
	}
}

{	# Try parsing with HighWire standard parser

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

}




print_out_article_parsing_result(\%article);



exit;







sub remove_orphan_ending_tag_only
{	my $htmlRef		= shift;
	while()
	{   if ($$htmlRef 	=~ /^\s*<\/.*?>/)
		{   $$htmlRef	= $';
		}else
		{   last;
		}
	}
}




#<tr><td class="content_box_title_highlight" colspan="2">This Article</td></tr>
#<tr><td class="content_box_title_highlight" colspan="2">This Article</td></tr>
#<tr><td class="content_box_title_highlight" colspan="2">Services</td></tr>
#<tr><td class="content_box_title_highlight" colspan="2">Citing Articles</td></tr>


sub ParseHighWireWithBigThisArticleBox()
{   my $htmlArticleRef = shift;
    my %article 		= (); 
    my @sideTables 		= (); 
    my $secAnchor   	= '';


	#  Remove any orphan ending tags
	remove_orphan_ending_tag_only($htmlArticleRef);
	my $htmlContent = ${$htmlArticleRef};
	
	#  Remove anything before the possible abstract
    if ($htmlContent =~ /<A NAME="(Abstract|ABS)">/i)
    {   $htmlContent = $&.$';
    }
    if (($htmlContent =~ /<A NAME="References">/i) || ( $htmlContent =~ /<A NAME="BIBL">/i) || ($htmlContent =~ /<STRONG>References<\/STRONG>/))
    {   $htmlContent = $`;
    }
    
    # Throw away footnotes for now!
    $htmlContent =~ s/<a name=\"RFN\d+\">(.*)?<a href="#FN\d+">//msgi;
    #$htmlContent =~ s/<a name=\"REF\d+\">.*?<a href=\"#FN\d+\">//msgi;

   	
    #
    # Figures and tables get special treatment...they also go at the end (order=99)
    #

    while( $htmlContent =~ /<center>.*?<table(.*?)\[in a new window\].*?<td align=left valign=top>(.*?)<\/td><\/tr><\/table>/msgi )
    {   
        my $figKey = '';
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
    {   
    	#print substr($line, 0, 550)."\n\n";
    	if ($line =~ /^\s*"(.*?)">/)
        {   my $tableAnchor = $1;
            my $content     = $';

            #  If not defined, use any pre-existing secAnchor
            my $tmpName = NormalizeName($tableAnchor);
            if ($tmpName eq "UNKNOWN")
            {   # Proceed with the anchor
                $article{UNKNOWN}->{order} = 97;
            }else
            {   $secAnchor  = $tmpName;
            }    
            
            #  Check for <FONT SIZE=+1><STRONG>Endothelium-Derived NO: An Antiatherosclerotic Molecule?</STRONG></FONT>
            if ($content =~ /<FONT .*?><STRONG>(.*?)<\/STRONG><\/FONT>/i)
            {	#  There are sub-sections
				my $preceding		= $`;
				my $matchString		= $&;
				my $remaining		= $&.$';
				            	
            	#  Process the preceding text
            	if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($`);
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($`);
		        }
		        
		        #  Try to extract name anchor
		        #  If not defined, use any pre-existing secAnchor
		        my $tmpName = NormalizeName($1);
		        if ($tmpName eq "UNKNOWN")
		        {   # Proceed with the anchor
		            $secAnchor	= 'UNKNOWN';
		            $article{$secAnchor}->{order} = 97;
		        }else
		        {   $secAnchor  = $tmpName;
		        	$article{$secAnchor}->{order} = $order++;
		        }  
		        

            	#  Process remaining text
            	while()
            	{   if ($remaining =~ /<FONT .*?><STRONG>(.*?)<\/STRONG><\/FONT>(.*?)(<FONT .*?><STRONG>(.*?)<\/STRONG><\/FONT>)/i)
            		{   #  Processed in-between text
            			$article{$secAnchor}->{text} .= CleanUp($2);
            			$remaining = $3.$';
            			
            			#  Process remaining anchor
            			my $tmpName = NormalizeName($4);
						if ($tmpName eq "UNKNOWN")
						{   # Proceed with the anchor
						    $article{UNKNOWN}->{order} = 97;
						    $secAnchor	= 'UNKNOWN';
						}else
						{   $secAnchor  = $tmpName;
							$article{$secAnchor}->{order} = $order++;
						}  
            		}else
            		{	#  Process the remaining text and exit
            			$article{$secAnchor}->{text} .= CleanUp($remaining);
            			last;
            		}
            	}
			}else
			{   if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($content);
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($content);
		        }
			}
        }else
        {   #  Check for abstract part
        	if ($line =~ /<FONT .*?><(STRONG|EM)>Abstract<\/(STRONG|EM)><\/FONT>/i)
        	{	$article{ABSTRACT}->{text} .= CleanUp($');
        		$article{ABSTRACT}->{order} = 1;
        	}elsif ($line =~ /'<a href="mailto:'.*?--><\/script>/i)
        	{	#  Check for email part
        		my $tmpContent	= $';
        		remove_orphan_ending_tag_only(\$tmpContent);
        		if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($tmpContent);
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($tmpContent);
		        	$article{UNKNOWN}->{order} = 97;
		        }
        	}
        }
    }

    #  Remove the reference section
    $article{REFERENCES}->{text} = '';
    $article{REFERENCES}->{order} = 89;
    
    return \%article;
}




sub ParseHighWireWithSideAnchors()
{   my $htmlArticleRef = shift;
    my %article = (); 
    my @sideTables = (); 
    my $secAnchor       = '';
    
	my $htmlContent = ${$htmlArticleRef};
	
    #  Remove anything before the possible abstract
    if ($htmlContent =~ /<A NAME="(Abstract|ABS)">/i)
    {   $htmlContent = $&.$';
    }
    
    if (($htmlContent =~ /<A NAME="References">/i) || ( $htmlContent =~ /<A NAME="BIBL">/i) || ($htmlContent =~ /<STRONG>References<\/STRONG>/))
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
    {   my $sideTable = $1;
        while( $sideTable =~ /<a +href=\"#(\w+?)\">(<img.*?arrow.gif\">)((\w|\s)+).*?<\/a>/msgi )  
        {   
            my $sectionAnchor= $1;
            my $sectionName= $3;
            $sectionAnchors{$sectionAnchor} = NormalizeName($sectionName);
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
    {   my $figKey = '';
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
                    $secAnchor	= "UNKNOWN";
                }else
                {   $secAnchor  = $tmpName;
                }    
            }
            
            if ($secAnchor ne "")
            {   $article{$secAnchor}->{text} .= CleanUp($content);
            }else
            {   $article{UNKNOWN}->{text} .= CleanUp($content);
            }
        }else
        {   #  Check for abstract part
        	if ($line =~ /<FONT .*?><STRONG>Abstract<\/STRONG><\/FONT>/i)
        	{	$article{ABSTRACT}->{text} .= CleanUp($');
        		$article{ABSTRACT}->{order} = 1;
        	}elsif ($line =~ /'<a href="mailto:'.*?--><\/script><\/FONT>/i)
        	{	#  Check for email part
        		if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($');
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($');
		        	$article{UNKNOWN}->{order} = 97;
		        }
        	}
        }
    }

    #  Remove the reference section
    $article{REFERENCES}->{text} = '';
    $article{REFERENCES}->{order} = 89;
    
    
    return \%article;
}








sub ParseHighWire()
{   my $htmlArticleRef = shift;
    my %article = (); 
    my @sideTables = (); 
    my $secAnchor       = '';
    
	my $htmlContent = ${$htmlArticleRef};
	
	#  Remove anything before the possible abstract
    if ($htmlContent =~ /<A NAME="(Abstract|ABS)">/i)
    {   $htmlContent = $&.$';
    }
    if (($htmlContent =~ /<A NAME="References">/i) || ( $htmlContent =~ /<A NAME="BIBL">/i) || ($htmlContent =~ /<STRONG>References<\/STRONG>/))
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
        my $figKey = '';;
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
                    $secAnchor	= "UNKNOWN";
                }else
                {   $secAnchor  = $tmpName;
                }    
            }
            
            if ($secAnchor ne "")
            {   $article{$secAnchor}->{text} .= CleanUp($content);
            }else
            {   $article{UNKNOWN}->{text} .= CleanUp($content);
            }
        }else
        {   #  Check for abstract part
        	if ($line =~ /<FONT .*?><STRONG>Abstract<\/STRONG><\/FONT>/i)
        	{	$article{ABSTRACT}->{text} .= CleanUp($');
        		$article{ABSTRACT}->{order} = 1;
        	}elsif ($line =~ /'<a href="mailto:'.*?--><\/script><\/FONT>/i)
        	{	#  Check for email part
        		if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($');
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($');
		        	$article{UNKNOWN}->{order} = 97;
		        }
        	}
        }
    }

    #  Remove the reference section
    $article{REFERENCES}->{text} = '';
    $article{REFERENCES}->{order} = 89;
    
    
    return \%article;
}






#  This subroutin parses HighWire documents with Article Navigator
sub ParseHighWireWithArticleNav
{   
	my $htmlArticleRef = shift;

    my %article 		= (); 
    my @sideTables 		= (); 
    my $secAnchor       = '';
	my $htmlContent 	= ${$htmlArticleRef};
	
	#  Process Article Navigator
	my %sectionAnchors = ();
	if ($htmlContent	=~ /<!-- #### ARTICLE NAV  #### -->(.*?)(<A NAME\s?=)/i)
	{   my $navContent	= $1;
		$htmlContent	= $2.$';
		
		while()
		{   if ($navContent =~ /<A HREF="\#(.*?)"><IMG.*?\.GIF">(.*?)<\/A>/i)
			{	$sectionAnchors{$1} = NormalizeName($2);
				$navContent 		= $';
			}else
			{   last;
			}
		}
	}


	#  Stripe out table content. These are usually tables
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
    {   #  Check for any missed splitting such as "<a name = "abs">"
    	if (($line =~ /^"(.*?)">/) || ($line =~ /^<a name = "(.*?)">/i))
        {   my $tableAnchor = $1;
            my $content     = $';

            #  Check for figure content
            if ($content =~ /<!-- FIG (\d+) -->/)
            {	#  There is figure content. Split the context into two
            	my $figureNum	= $1;
            	my @localSplit	= split (/<!-- \/FIG $figureNum -->/, $');
            	
            	#  Process figure part
            	$article{FIGURES}->{text} 	.= CleanUp($localSplit[0]);
            	$article{FIGURES}->{order}	= 98;
            	
            	#  Process remaining text
            	if ((defined $secAnchor) && ($secAnchor ne ""))
            	{   $article{$secAnchor}->{text} 	.= CleanUp($localSplit[1]);
            	}else
            	{	$article{UNKNOWN}->{text} 	.= CleanUp($localSplit[1]);
            		$article{UNKNOWN}->{order}	= 97;
            	}
            }else
            {	if (defined $sectionAnchors{$tableAnchor} )
		        {   #  There is a matching section anchor for this one
		            $secAnchor  = $sectionAnchors{$tableAnchor};
		            $article{$secAnchor}->{order} = $order++;
		        }else
		        {   #  If not defined, use any pre-existing secAnchor
		            my $tmpName = NormalizeName($tableAnchor);
		            if ($tmpName eq "UNKNOWN")
		            {   # Proceed with the anchor
		                $article{UNKNOWN}->{order} = 97;
		                $secAnchor						= "UNKNOWN";
		            }else
		            {   $secAnchor  					= $tmpName;
		            	$article{$secAnchor}->{order}	= $order++;
		            }    
		        }
		        
		        if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($content);
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($content);
		        }
            }
        }else
        {   #  Check for abstract part
        	if ($line =~ /<FONT .*?><STRONG>Abstract<\/STRONG><\/FONT>/i)
        	{	$article{ABSTRACT}->{text} .= CleanUp($');
        		$article{ABSTRACT}->{order} = 1;
        	}elsif ($line =~ /'<a href="mailto:'.*?--><\/script><\/FONT>/i)
        	{	#  Check for email part
        		if ($secAnchor ne "")
		        {   $article{$secAnchor}->{text} .= CleanUp($');
		        }else
		        {   $article{UNKNOWN}->{text} .= CleanUp($');
		        	$article{UNKNOWN}->{order} = 97;
		        }
        	}
        }
    }

    #  Remove the reference section
    $article{REFERENCES}->{text} = '';
    $article{REFERENCES}->{order} = 89;
    
    
    return \%article;
}



#  -----------------------------------------------------------------------------
sub print_out_article_parsing_result
{   my $articleRef		= shift;

	# Print out the resulting XML file
	print "<DOC>\n<PMID>$PMID<\/PMID>\n";

	my $outputContent = '';
	# Check whether this is required. #
	foreach my $section( sort( { $$articleRef{$a}->{order} <=> $$articleRef{$b}->{order} } keys( %{$articleRef}) ) )
	{   my $modified = $$articleRef{$section}->{text};
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
}



sub ParseHighWireLastTry
{   #  This is to be used after both new and old ParseHighWire failed.
    my $htmlArticleRef  = shift;
    
    my %article         = (); 
    my @sideTables      = (); 
    my $htmlContent     = '';
    my $secAnchor       = '';

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













	
sub ParseOldHighWire()
{   my $htmlArticleRef = shift;
    my %article = (); 
    my @sideTables = (); 

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
        my $figKey = '';
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
	elsif( $sectionName =~ /acknowledge?ment/i ) 		    { $sectionName = "ACKNOWLEDGMENTS"; $knownName = 1; }
	elsif( $sectionName =~ /footnote/i ) 		    		{ $sectionName = "FOOTNOTES"; $knownName = 1; }
	elsif( $sectionName =~ /abbreviation/i ) 		   		{ $sectionName = "ABBREVIATIONS"; $knownName = 1; }
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


#!/usr/bin/perl -w

# Converts a *.split.xml file into a .prelink file to STDOUT for link parsing
# the suitable sentence-numbered version, ready for hand edit

my $file = $ARGV[0];

local $LinkSettings = 
"!islands-ok=1
!graphics=0
!echo=1
!links=1
!width=200
!walls=0
!limit=1000
!constituents=0
!timeout=5
";

local $INREF = 0;

my $root = 0;
my $retStr = "";
my $sCount = 0;

if( $file =~ /(\d+)\.split.xml/ )
{
	$root = $1;
	# print STDERR "Processing $root...";
}
else
{
	exit;
}

open( INFILE, "$file") or die "cannot open $root.split.xml: $!\n";

while( my $line = <INFILE> )
{
	chomp($line);

	#some Link-specific pre-processing
        # XML escapes
#        print $line."\n";
#        if ($line =~ /&#([0-9]+);/)
#    {   print STDERR $line."\n";
#        $line =~ s/&#([0-9]+);/Enc1($1)/g;
#        print STDERR $1."\n\n";
#    }
        $line =~ s/&amp;amp;#223;/beta/g;
        $line =~ s/&amp;amp;#176;/deg/g;
        $line =~ s/&amp;amp;#177;/ plus_or_minus /g;
        $line =~ s/&amp;amp;#183;/ - /g;
        $line =~ s/&amp;amp;#151;/ -- /g;
        $line =~ s/&amp;amp;#215;/*/g;

        $line =~ s/&lt;/_lt_/g;
        $line =~ s/&gt;/_gt_/g;
        $line =~ s/&amp;/&/g;
        $line =~ s/&/_amp_/g;

        $line =~ s/&(\S+);/$1/g;
	
#    print STDERR $1."\n";
	#urls in general don't mix well and trigger exception faults
	$line =~ s/(ht|f)tp:\/\/[\w_\-.\/]+/URL/g;

	# Parentes used to be removed by the following expression 
	# But not any more. Information in parentheses are sometimes very informatative.
	# $line =~ s/(\(|\{|\[)[^\(\{\[\]\}\)]*?(\)|\]|\})//g;
	
	if( $line =~ /^\s*<(.*)>/ ) #XML Tag
	{
		 if( $1 eq 'REFERENCES' || $1 eq 'METHODS' )
		 {
		    $INREF = 1;
		 }
 
		 if( $1 eq '/REFERENCES' || $1 eq 'METHODS')
		 {
		    $INREF = 0;
		 }
		$retStr .= "\%$line\n";
		next;
	}
	
	if( $line =~ /^(.*)$/ )
	{
		 if( $INREF )
		 {
		   $retStr .= "\%$1\n";
		   next;
		 }
		if( $line ne '' )
		{
			$retStr .= "$1\n";
		}
	}
}

open (OUTFILE, ">".$ARGV[1]);
print OUTFILE $LinkSettings;
print OUTFILE $retStr;
print OUTFILE "\nexit";
close (OUTFILE);
close (INFILE);

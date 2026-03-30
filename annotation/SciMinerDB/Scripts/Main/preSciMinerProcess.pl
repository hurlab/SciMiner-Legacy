#!/usr/bin/perl -w

# This script will convert *.prelink into *.preSciMiner format that is more JUMiberDB friendly


open (INFILE, $ARGV[0]);
open (OUTFILE, ">".$ARGV[1]);

my $anchor  = '';
my $ppn     = 0;

while(<INFILE>)
{   my $line = $_;
    $line =~ s/\r|\n//g;
    $line =~ s/_amp_/\&/g;
    
    if ($line =~ /^\%<(\w+)>/)
    {   $anchor = $1;
    }elsif ($line =~ /^\%<p ppn=\"(\d+)\">/)
    {   $ppn    = $1;
    }elsif ($line =~ /^(\d+)/)
    {   print OUTFILE "$1 $anchor $ppn ".$'."\n"; 
    }
}
close INFILE;
close OUTFILE;


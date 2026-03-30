#!/usr/bin/perl -w
# This script will delete any medline file whose size is smaller than 100 bytes.

use warnings;
use strict;

my @files = glob("*.medline");
my $fileCount	= scalar @files;

my $deletedCount=0;
my $deletedIDs = "";
for (my $i=0; $i < $fileCount; $i++)
{   if ((-s $files[$i]) < 100)
    {    unlink($files[$i]);
	 $deletedCount++;
         $deletedIDs .= $files[$i]."\n";
    }


}
print "Total deleted : $deletedCount\n\n";
print $deletedIDs;


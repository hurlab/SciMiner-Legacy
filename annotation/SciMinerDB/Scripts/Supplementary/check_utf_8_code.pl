#!/usr/bin/perl -w

use warnings;
use strict;
use DBI;


my $SciMinerDB   = "DBI:mysql:database=sciminer" || return (-1, "!ERROR: No database specified");
my $username    = "sciminer" || return (-1, "!ERROR: No username specified");
my $password    = "124356!@" || return (-1, "!ERROR: No password specified");

#  ------------------------------------------------------------------------
#  Retrieve User Information from SciMinerDB
#  ------------------------------------------------------------------------
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                  print STDERR "!ERROR: Couldn't connect to database ".$DBI::errstr;

my $PMIDString	= '';
if ((defined $ARGV[0]) && (-f $ARGV[0]))
{	open (FILE, $ARGV[0]);
	my @pmids	= ();
	while(<FILE>)
	{	my $line = $_;
		$line =~ s/\r|\n//g;
		push @pmids, $line;
	}
	close FILE;
	$PMIDString	= join (",", @pmids);
}

#  Delete the query -- actually only update the 'deleted' column data
my $sql = "SELECT senID, pmid, sentence FROM sentence";
if ($PMIDString ne "")
{	$sql = "SELECT senID, pmid, sentence FROM sentence WHERE pmid in ($PMIDString)";
	print $PMIDString."\n";
}
my $sth = $dbh->prepare($sql);
my @row = ();
$sth->execute();

open (RESULT, ">UTF_8_Characters.txt");
open (SUMMARY, ">UTF_8_Characters_Count.txt");

my %UTF8Count			= ();
my $specialCharString	= '';
while(@row = $sth->fetchrow_array)
{   if (defined $row[2])
	{	if ($row[2] =~ /_amp_\#\S+?\;/)
		{	$specialCharString	= $&;
			if (not defined $UTF8Count{$specialCharString})
			{	$UTF8Count{$specialCharString}	= 1;
			} else
			{	$UTF8Count{$specialCharString}++;
			}
			print RESULT $row[0]."\t".$row[1]."\t".$specialCharString."\t".$row[2]."\n";
		}
	}
}
close RESULT;

foreach my $specialString (keys %UTF8Count)
{	print SUMMARY $specialString."\t".$UTF8Count{$specialString}."\n";

}
close SUMMARY;

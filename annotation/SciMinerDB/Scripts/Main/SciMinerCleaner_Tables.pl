#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerCleaner_Tables
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           sciminer @ umich . edu
#
#      
#   Desc: This script will close the mornitoring scripts and 
#	  COMPLETELY delete records in the SciMinerDB 
#	  for the following tables.
#
#	  	document, docmesh, sentence, sentence2gene, 
#		documentpubmed, docmeshg2p, 
#		#query, analysis
#	
#
#############################################################################
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}

use Annotation::basicIO;            
use Annotation::SciMiner;   
use strict;
use warnings;

#  Load working environment for ANNOTATION
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};

#  Database Access Information
my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


print 	"\n!! The server url is $annoENV{SciMinerServerURL}\n\n".
	  	"Are you sure to STOP the SciMiner running processes\n".
		"document related SciMinerDB tables (y/N)?";
chomp(my $choice	= <STDIN>);
if (uc($choice) ne "Y")
{   die "! Process aborted by user.\n\n";
}
	  

#  Kill the process MonitorSciMinerQueue.pl
my @files           = `ps -ef | grep '/usr/bin/perl /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB//Scripts/Main/MonitorSciMinerQueue.pl'`;
print "\n\n";
if (defined $files[0])
{   foreach my $line (@files)
    {   if (($line =~ /^sciminer\s+(\d+)\s+/) && ($line !~ /grep/))
        {   `kill -9 $1`;
            print "! MonitorSciMinerQueue.pl has been killed ...\n";
            last;
        }
    }
}

#  Kill the process MonitorSciMinerGRIFQueue.pl
@files           = `ps -ef | grep '/usr/bin/perl /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB//Scripts/Main/MonitorSciMinerGRIFQueue.pl'`;
print "\n\n";
if (defined $files[0])
{   foreach my $line (@files)
    {   if (($line =~ /^sciminer\s+(\d+)\s+/) && ($line !~ /grep/))
        {   `kill -9 $1`;
            print "! MonitorSciMinerGRIFQueue.pl has been killed ...\n";
            last;
        }
    }
}

#  Kill the process MonitorSciMinerAnalysis.pl
@files           = `ps -ef | grep '/usr/bin/perl /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB//Scripts/Main/MonitorSciMinerAnalysis.pl'`;
print "\n\n";
if (defined $files[0])
{   foreach my $line (@files)
    {   if (($line =~ /^sciminer\s+(\d+)\s+/) && ($line !~ /grep/))
        {   `kill -9 $1`;
            print "! MonitorSciMinerAnalysis.pl has been killed ...\n";
            last;
        }
    }
}



#  -----------------------------------------------------------------------------
#  Remove Temporary Files
#  -----------------------------------------------------------------------------
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/Current*`;
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/Query_*`;
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/GRIFQuery_*`;
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/Analysis*`;


print "\n\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\t".
          "This will delete the following tables\n".
          "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n";

my @tablesToTruncate = ("document", "sentence", "sentence2gene", "docmesh",
						"documentpubmed", "docmeshg2p");


foreach my $tableName (@tablesToTruncate)
{   print "\t$tableName\n";
}
print "\n\n";

print "Are you sure to continue to DELETE ALL OF THE ABOVE TABLES (y/N)?";
my $selection = <STDIN>;
$selection =~ s/\r|\n//g;

if (($selection eq 'Y') || ($selection eq 'y'))
{   # continue
}else
{   die "\nAborted by users...\n\n";
}


#  Connect to MySQL SciMiner Database
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                    return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

foreach my $tableName (@tablesToTruncate)
{   $dbh->do("TRUNCATE $tableName");
}
print "\nThese tables have been truncated from SciMinerDB\n\n\n";
exit;

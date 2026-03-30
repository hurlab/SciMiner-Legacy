#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerCleaner
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           juhur @ umich . edu
#
#      
#   Desc: This script will delete records corresponding to the given PMIDs
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




#  Kill the process SciMinerQueueMonitor
my @files		= `ps -ef | grep '/usr/bin/perl /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB//Scripts/Main/MonitorSciMinerQueue.pl'`;
print "\n\n";
if (defined $files[0])
{   foreach my $line (@files)
    {   if (($line =~ /^sciminer\s+(\d+)\s+/) && ($line !~ /grep/))
        {   `kill -9 $1`;
            print "! MonitorSciMinerQueue.pl has been killed ...\n";
            last;
        }
    }
}else
{   print "! No MonitorSciMinerQueue.pl is running ...\n";
}



#  Kill the process SciMinerGRIFQueueMonitor
@files		= `ps -ef | grep '/usr/bin/perl /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB//Scripts/Main/MonitorSciMinerGRIFQueue.pl'`;
print "\n\n";
if (defined $files[0])
{   foreach my $line (@files)
    {   if (($line =~ /^sciminer\s+(\d+)\s+/) && ($line !~ /grep/))
        {   `kill -9 $1`;
            print "! MonitorSciMinerGRIFQueue.pl has been killed ...\n";
            last;
        }
    }
}else
{   print "! No MonitorSciMinerGRIFQueue.pl is running ...\n";
}


#  Kill the process
@files		= `ps -ef | grep '/usr/bin/perl /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB//Scripts/Main/MonitorSciMinerAnalysis.pl'`;
print "\n\n";
if (defined $files[0])
{   foreach my $line (@files)
    {   if (($line =~ /^sciminer\s+(\d+)\s+/) && ($line !~ /grep/))
        {   `kill -9 $1`;
            print "! MonitorSciMinerAnalysis.pl has been killed ...\n";
            last;
        }
    }
}else
{   print "! No MonitorSciMinerAnalysis.pl is running ...\n";
}


#  -----------------------------------------------------------------------------
#  Remove Temporary Files
#  -----------------------------------------------------------------------------
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/Current*`;
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/Query_*`;
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/GRIFQuery_*`;
`rm -Rf /home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Work/Analysis*`;




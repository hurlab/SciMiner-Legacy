#!/usr/bin/perl -w
#############################################################################
#
#                  SciMiner Query and Analysis Clean-Up
# 
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           juhur @ umich . edu
#
#      
#   Desc: This script will clean up deleted query and analysis from
#		  the hard drive. This script should be launched manually but
#		  will be automated in the future release. 
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
my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);
                      
#  Retrieve user information
my $sql         = "SELECT userID, email from user";
my $sth         = $dbh->prepare($sql);
   $sth->execute();
my %user2uniq	= ();
my @row         = ();
while(@row = $sth->fetchrow_array)
{   if (defined $row[1])
    {   my @tmpSplit 		= split (/\@/, $row[1]);
    	$user2uniq{$row[0]}	= $tmpSplit[0];
    }
}

LogQuery("!DELETING! SciMinerDeletedQueryAnalysisCleanUp.pl has been initiated...");
#  Process deleted query
$sql         = "SELECT queryID, userID FROM query where deleted = 1";
$sth         = $dbh->prepare($sql);
$sth->execute();
my @queryID		= ();
my @userID		= ();
my @baseName	= ();
while(@row = $sth->fetchrow_array)
{   if (defined $row[1])
    {   if (defined $user2uniq{$row[1]})
    	{   push @queryID, $row[0];
    		push @userID, $row[1];
    		push @baseName, 'Query_'.$row[0].'__'.$user2uniq{$row[1]};
    		push @baseName, 'GRIFQuery_'.$row[0].'__'.$user2uniq{$row[1]};    		
    	}
    }
}


my $cleanedQueryCnt	= 0;
#  Delete directories if they still exist
for (my $i=0; $i <= $#baseName; $i++)
{   #  Check the final directory first
	my $finalResultDir 		= $annoENV{SciMinerPath}."Work/FinalResults/$baseName[$i]/";
	my $finalWebResultDir	= $annoENV{SciMinerWebPath}."FinalResults/$baseName[$i]/";
	
	if (-d $finalResultDir)
	{   if ($baseName[$i] =~ /^GRIF/)
		{	LogQuery("!DELETING! $baseName[$i] FinalResults directory...");
		}else
		{	LogGRIFQuery("!DELETING! $baseName[$i] FinalResults directory...");
		}
		print "Deleting ".$finalResultDir."\n";
		`rm -Rf $finalResultDir`;
		$cleanedQueryCnt++;
	}
	
	if (-d $finalWebResultDir)
	{   if ($baseName[$i] =~ /^GRIF/)
		{	LogQuery("!DELETING! $baseName[$i] FinalResults Web directory...");
		}else
		{	LogGRIFQuery("!DELETING! $baseName[$i] FinalResults Web directory...");
		}
		`rm -Rf $finalWebResultDir`;
	}
	
}





#  Process deleted analysis
$sql         = "SELECT analID, userID FROM analysis where deleted = 1";
$sth         = $dbh->prepare($sql);
$sth->execute();
my @analID		= ();
@userID		= ();
@baseName	= ();
while(@row = $sth->fetchrow_array)
{   if (defined $row[1])
    {   if (defined $user2uniq{$row[1]})
    	{   push @analID, $row[0];
    		push @userID, $row[1];
    		push @baseName, 'Analysis_'.$row[0].'__'.$user2uniq{$row[1]};
    	}
    }
}

my $cleanedAnalysisCnt	= 0;
#  Delete directories if they still exist
for (my $i=0; $i <= $#analID; $i++)
{   #  Check the final directory first
	my $finalResultDir 		= $annoENV{SciMinerPath}."Work/FinalResults/$baseName[$i]/";
	my $finalWebResultDir	= $annoENV{SciMinerWebPath}."FinalResults/$baseName[$i]/";
	
	if (-d $finalResultDir)
	{   LogAnalysis("!DELETING! analID = $analID[$i] FinalResults directory...");
		print "Deleting ".$finalResultDir."\n";
		`rm -Rf $finalResultDir`;
		$cleanedAnalysisCnt++;
	}
	
	if (-d $finalWebResultDir)
	{   LogAnalysis("!DELETING! analID = $analID[$i] FinalResults Web directory...");
		`rm -Rf $finalWebResultDir`;
	}
	
}

LogQuery("!DELETE! Total cleaned up $cleanedQueryCnt queries and $cleanedAnalysisCnt analyses\n");
LogAnalysis("!DELETE! Total cleaned up $cleanedQueryCnt queries and $cleanedAnalysisCnt analyses\n");
exit;







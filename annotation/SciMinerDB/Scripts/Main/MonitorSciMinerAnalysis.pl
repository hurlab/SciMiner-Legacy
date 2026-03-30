#!/usr/bin/perl -w
#############################################################################
#
#                       SciMinerAnalysisMonitor
#
#                                           Junguk Hur
#                                           Bioinformatics Graduate Program
#                                           University of Michigan, Ann Arbor
#                                           juhur @ umich . edu
#
#
#   Desc: This script should be up all the time to monitor the queue list
#         directory. If any new queue is found, then this will automatically
#         launch the afterward necessary steps.
#
#############################################################################
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}

use Annotation::basicIO;
use Annotation::SciMiner;
use Annotation::Logger;
use strict;
use warnings;

#  Load working environment for ANNOTATION
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};

#  Database Access Information
my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

#  Setting variables
my $sleepInterval = 10;     # 60 seconds
my $jobTimeout    = 3600;   # 1 hour max per job

log_info('MonitorAnalysis', 'SciMiner Analysis Monitor started');

#  Loop infinitely
while()
{   #  Read the file list
    my @confFiles       = glob ("$annoENV{SciMinerPath}/Work/Analysis*.conf");

    if (not defined $confFiles[0])
    {   if (-f "$annoENV{SciMinerPath}/Work/AnalysisList")
        {   unlink ("$annoENV{SciMinerPath}/Work/AnalysisList");
        }
        if (-f "$annoENV{SciMinerPath}/Work/AnalysisQueue")
        {   unlink ("$annoENV{SciMinerPath}/Work/AnalysisQueue");
        }
        sleep($sleepInterval);
        next;
    }

    my @shortFileNames  = short_name_ext(\@confFiles, '.conf');
    my %queryNum2File   = ();

    #  Sort the file by query number
    foreach my $fileName (@shortFileNames)
    {   if ($fileName =~ /^Analysis_(\d+)__/)
        {   $queryNum2File{$1} = $fileName;
        }
    }
    my @sortedQueryNum = sort {$a <=> $b} keys %queryNum2File;

    #  Check the queueListFile
    if (! -f "$annoENV{SciMinerPath}/Work/AnalysisQueue")
    {   open (QUEUE, ">$annoENV{SciMinerPath}/Work/AnalysisQueue");
        print QUEUE $sortedQueryNum[0];
        close QUEUE;

        #  Process query in the 'CurrentQueue' file with error handling
        eval {
            local $SIG{ALRM} = sub { die "Job timed out after ${jobTimeout}s\n" };
            alarm($jobTimeout);

            log_info('MonitorAnalysis', "Processing analysis queue: $sortedQueryNum[0]");
            my ($processStatus, $message) = process_current_analysis_queue();
            log_info('MonitorAnalysis', "Analysis queue completed: status=$processStatus");

            alarm(0);
        };
        if ($@) {
            my $err = $@;
            alarm(0);  # Ensure alarm is cancelled
            log_error('MonitorAnalysis', "Error in analysis processing: $err");
            warn "MonitorSciMinerAnalysis: Error in analysis processing: $err";
            # Clean up the queue file so the monitor can move on
            if (-f "$annoENV{SciMinerPath}/Work/AnalysisQueue") {
                unlink("$annoENV{SciMinerPath}/Work/AnalysisQueue");
            }
        }
    }else
    {   # If there is a queue file, then just wait for it to be completed.
    }
    sleep ($sleepInterval);

}

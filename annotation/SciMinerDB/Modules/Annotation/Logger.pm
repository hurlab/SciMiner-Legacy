package Annotation::Logger;
################################################################################
#
#       Structured Logging Module for SciMiner
#
#       Provides log_info, log_warn, log_error, log_debug functions
#       with timestamps, log levels, and component tagging.
#
#       Log directory configurable via SCIMINER_LOG_DIR env var.
#       Log level configurable via SCIMINER_LOG_LEVEL env var.
#
#                                           Written by: Junguk Hur
#
################################################################################
use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(make_path);
use Exporter 'import';
our @EXPORT = qw(log_info log_warn log_error log_debug);

# Log directory - configurable via env var
my $LOG_DIR   = $ENV{SCIMINER_LOG_DIR}   || '/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/web/var/log';
my $LOG_LEVEL = $ENV{SCIMINER_LOG_LEVEL} || 'INFO';  # DEBUG, INFO, WARN, ERROR

my %LEVELS = (DEBUG => 0, INFO => 1, WARN => 2, ERROR => 3);

sub _log {
    my ($level, $component, $message) = @_;
    return if (defined $LEVELS{$level} ? $LEVELS{$level} : 0) < (defined $LEVELS{$LOG_LEVEL} ? $LEVELS{$LOG_LEVEL} : 1);

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $log_file  = "$LOG_DIR/sciminer.log";

    # Ensure log directory exists
    make_path($LOG_DIR) unless -d $LOG_DIR;

    if (open(my $fh, '>>', $log_file)) {
        print $fh "[$timestamp] [$level] [$component] $message\n";
        close($fh);
    } else {
        warn "Cannot write to log file $log_file: $!";
    }
}

sub log_info  { _log('INFO',  @_) }
sub log_warn  { _log('WARN',  @_) }
sub log_error { _log('ERROR', @_) }
sub log_debug { _log('DEBUG', @_) }

1;

#!/usr/bin/env perl
################################################################################
#
#   03-logger.t - Logger Module Tests
#
#   Test the Annotation::Logger module:
#     - log_info(), log_warn(), log_error() write to log file
#     - Log format: [timestamp] [LEVEL] [component] message
#     - Log file is created if missing
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More tests => 12;
use File::Temp qw(tempdir);
use File::Spec;

# Use a temporary directory for test log files
my $tmpdir = tempdir(CLEANUP => 1);

# Override the log directory via environment variable
$ENV{SCIMINER_LOG_DIR}   = $tmpdir;
$ENV{SCIMINER_LOG_LEVEL} = 'DEBUG';  # Enable all log levels

# Load the Logger module
use_ok('Annotation::Logger') or BAIL_OUT('Cannot load Annotation::Logger');

# --------------------------------------------------------------------------
# Test: log_info writes to log file
# --------------------------------------------------------------------------
{
    log_info('TestComponent', 'This is an info message');

    my $log_file = File::Spec->catfile($tmpdir, 'sciminer.log');
    ok(-f $log_file, 'Log file was created');

    open my $fh, '<', $log_file or die "Cannot read log file: $!";
    my @lines = <$fh>;
    close $fh;

    ok(scalar @lines >= 1, 'Log file has at least one line');
    like($lines[-1], qr/\[INFO\]/, 'log_info writes INFO level');
    like($lines[-1], qr/\[TestComponent\]/, 'log_info includes component name');
    like($lines[-1], qr/This is an info message/, 'log_info includes message text');
}

# --------------------------------------------------------------------------
# Test: log_warn writes to log file
# --------------------------------------------------------------------------
{
    log_warn('Security', 'Suspicious login attempt');

    my $log_file = File::Spec->catfile($tmpdir, 'sciminer.log');
    open my $fh, '<', $log_file or die "Cannot read log file: $!";
    my @lines = <$fh>;
    close $fh;

    my $warn_line = (grep { /\[WARN\]/ } @lines)[0];
    ok(defined $warn_line, 'log_warn wrote a WARN line');
    like($warn_line, qr/\[Security\]/, 'log_warn includes component name');
}

# --------------------------------------------------------------------------
# Test: log_error writes to log file
# --------------------------------------------------------------------------
{
    log_error('Database', 'Connection failed');

    my $log_file = File::Spec->catfile($tmpdir, 'sciminer.log');
    open my $fh, '<', $log_file or die "Cannot read log file: $!";
    my @lines = <$fh>;
    close $fh;

    my $err_line = (grep { /\[ERROR\]/ } @lines)[0];
    ok(defined $err_line, 'log_error wrote an ERROR line');
    like($err_line, qr/Connection failed/, 'log_error includes message text');
}

# --------------------------------------------------------------------------
# Test: Log format validation
# --------------------------------------------------------------------------
{
    my $log_file = File::Spec->catfile($tmpdir, 'sciminer.log');
    open my $fh, '<', $log_file or die "Cannot read log file: $!";
    my @lines = <$fh>;
    close $fh;

    # Expected format: [YYYY-MM-DD HH:MM:SS] [LEVEL] [component] message
    my $format_re = qr/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[(DEBUG|INFO|WARN|ERROR)\] \[\w+\] .+$/;
    like($lines[0], $format_re, 'Log line matches expected format');
}

# --------------------------------------------------------------------------
# Test: log_debug behavior
# --------------------------------------------------------------------------
# NOTE: Known bug in Logger.pm -- the level check uses:
#   return if ($LEVELS{$level} || 0) < ($LEVELS{$LOG_LEVEL} || 1);
# When LOG_LEVEL is 'DEBUG' (value 0), the "|| 1" fallback makes it 1,
# so DEBUG messages (level 0) are always filtered out even at DEBUG level.
# This is a production bug -- log_debug never writes output.
{
    log_debug('Parser', 'Debug trace message');

    my $log_file = File::Spec->catfile($tmpdir, 'sciminer.log');
    open my $fh, '<', $log_file or die "Cannot read log file: $!";
    my @lines = <$fh>;
    close $fh;

    my $debug_line = (grep { /\[DEBUG\]/ } @lines)[0];
    TODO: {
        local $TODO = 'Known bug: Logger.pm level check treats DEBUG (0) as falsy via || operator';
        ok(defined $debug_line, 'log_debug writes a DEBUG line at DEBUG level');
    }
}

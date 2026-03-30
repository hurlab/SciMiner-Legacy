#!/usr/bin/perl
# ==============================================================================
# update_generif.pl
# ==============================================================================
# Purpose:  Download fresh GeneRIF (Gene Reference Into Function) data from NCBI
#           and rebuild the GENERIF_default dictionary used by SciMiner.
#
# Data Source:
#   NCBI FTP: https://ftp.ncbi.nlm.nih.gov/gene/GeneRIF/generifs_basic.gz
#
# Output File:
#   GENERIF_default  - Tab-delimited: NCBI_Gene_ID\tGeneRIF_sentence
#                      Filtered for human entries only (Tax ID 9606)
#
# Usage:
#   perl update_generif.pl [options]
#
# Options:
#   --dry-run     Show what would be done without writing files
#   --no-backup   Skip backup of old file
#   --dict-dir    Override dictionary directory path
#   --help        Show this help message
#
# Dependencies: LWP::UserAgent, IO::Uncompress::Gunzip (core Perl + LWP)
#
# Author: SciMiner Dictionary Update System
# Date:   2026-03-15
# ==============================================================================

use strict;
use warnings;
use LWP::UserAgent;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use File::Copy;
use File::Path qw(make_path);
use Getopt::Long;
use POSIX qw(strftime);
use Cwd 'abs_path';

# ==============================================================================
# Configuration
# ==============================================================================
my $SCRIPT_DIR = $0;
$SCRIPT_DIR =~ s/[^\/]+$//;
$SCRIPT_DIR = '.' if $SCRIPT_DIR eq '';

my $DEFAULT_DICT_DIR = "$SCRIPT_DIR/../annotation/SciMinerDB/Work/Dictionary";

my $GENERIF_URL = 'https://ftp.ncbi.nlm.nih.gov/gene/GeneRIF/generifs_basic.gz';

# Human taxonomy ID
my $HUMAN_TAX_ID = '9606';

# ==============================================================================
# Command-line options
# ==============================================================================
my $dry_run     = 0;
my $no_backup   = 0;
my $dict_dir    = $DEFAULT_DICT_DIR;
my $help        = 0;

GetOptions(
    'dry-run'     => \$dry_run,
    'no-backup'   => \$no_backup,
    'dict-dir=s'  => \$dict_dir,
    'help'        => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print <<'USAGE';
Usage: perl update_generif.pl [options]

Options:
  --dry-run     Show what would be done without writing files
  --no-backup   Skip backup of old file
  --dict-dir    Override dictionary directory path
  --help        Show this help message

Downloads fresh GeneRIF data from NCBI and builds the GENERIF_default
dictionary for SciMiner. Only human entries (Tax ID 9606) are included.
USAGE
    exit 0;
}

# ==============================================================================
# Main
# ==============================================================================
print "=" x 60, "\n";
print "SciMiner GeneRIF Dictionary Update\n";
print "=" x 60, "\n";
print "Date:       ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";
print "Dict Dir:   $dict_dir\n";
print "Dry Run:    ", ($dry_run ? "YES" : "NO"), "\n";
print "-" x 60, "\n\n";

$dict_dir = abs_path($dict_dir) if -d $dict_dir;
unless (-d $dict_dir) {
    die "ERROR: Dictionary directory does not exist: $dict_dir\n";
}

# Step 1: Backup existing file
if (!$no_backup && !$dry_run) {
    my $existing = "$dict_dir/GENERIF_default";
    if (-f $existing) {
        my $date_str = strftime("%Y%m%d_%H%M%S", localtime);
        my $backup_dir = "$dict_dir/backup_$date_str";
        make_path($backup_dir) unless -d $backup_dir;
        copy($existing, "$backup_dir/GENERIF_default")
            or warn "WARNING: Could not backup GENERIF_default: $!\n";
        print "[Backup] Backed up GENERIF_default to $backup_dir/\n\n";
    }
}

# Step 2: Download GeneRIF data
print "[Step 1/3] Downloading GeneRIF data from NCBI FTP...\n";
my $ua = LWP::UserAgent->new(
    timeout    => 600,
    agent      => 'SciMiner-DictionaryUpdate/1.0',
    ssl_opts   => { verify_hostname => 0 },
);

my $response = $ua->get($GENERIF_URL);
unless ($response->is_success) {
    die "ERROR: Failed to download GeneRIF data: " . $response->status_line . "\n";
}

my $compressed = $response->content;
printf "  Downloaded: %.2f MB (compressed)\n", length($compressed) / (1024 * 1024);

# Step 3: Decompress
print "[Step 2/3] Decompressing...\n";
my $decompressed;
gunzip(\$compressed, \$decompressed)
    or die "ERROR: Failed to decompress GeneRIF data: $GunzipError\n";
printf "  Uncompressed: %.2f MB\n", length($decompressed) / (1024 * 1024);

# Step 4: Parse and filter for human entries
print "[Step 3/3] Parsing and filtering for human entries...\n";

my $outfile = "$dict_dir/GENERIF_default";
my $total_lines = 0;
my $human_lines = 0;
my $unique_genes = {};

if ($dry_run) {
    # Just count
    for my $line (split /\n/, $decompressed) {
        next if $line =~ /^#/;
        $total_lines++;
        my @fields = split /\t/, $line;
        if ($fields[0] eq $HUMAN_TAX_ID) {
            $human_lines++;
            $unique_genes->{$fields[1]} = 1;
        }
    }
    print "  [DRY RUN] Would write to $outfile\n";
} else {
    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # generifs_basic format:
    #   Column 0: Tax ID
    #   Column 1: Gene ID (Entrez Gene ID)
    #   Column 2: PubMed ID (comma-separated)
    #   Column 3: Last update timestamp
    #   Column 4: GeneRIF text
    #
    # SciMiner GENERIF_default format:
    #   Gene_ID\tGeneRIF_sentence

    for my $line (split /\n/, $decompressed) {
        next if $line =~ /^#/;
        $line =~ s/\r//g;
        $total_lines++;

        my @fields = split /\t/, $line, -1;
        next unless scalar(@fields) >= 5;

        # Filter for human only
        if ($fields[0] eq $HUMAN_TAX_ID) {
            my $gene_id   = $fields[1];
            my $generif   = $fields[4];

            # Skip empty GeneRIF text
            next unless defined $generif && $generif ne '';

            # Clean up the text
            $generif =~ s/\r|\n/ /g;
            $generif =~ s/\s+/ /g;
            $generif =~ s/^\s+|\s+$//g;

            print $fh "$gene_id\t$generif\n";
            $human_lines++;
            $unique_genes->{$gene_id} = 1;
        }
    }

    close $fh;
}

# Summary
print "\n";
print "=" x 60, "\n";
print "Summary:\n";
print "  Total GeneRIF entries:     $total_lines\n";
print "  Human entries written:     $human_lines\n";
print "  Unique human genes:        ", scalar(keys %$unique_genes), "\n";
if (!$dry_run) {
    my $size = -s $outfile || 0;
    printf "  Output file size:          %.2f MB\n", $size / (1024 * 1024);
}
print "=" x 60, "\n";

if ($dry_run) {
    print "\n*** DRY RUN - No files were written ***\n";
}

exit 0;

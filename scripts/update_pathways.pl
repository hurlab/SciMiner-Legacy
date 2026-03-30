#!/usr/bin/perl
# ==============================================================================
# update_pathways.pl
# ==============================================================================
# Purpose:  Download fresh KEGG and Reactome pathway data and rebuild
#           the pathway dictionary files used by SciMiner.
#
# Data Sources:
#   KEGG REST API:  https://rest.kegg.jp/list/pathway/hsa
#   Reactome:       https://reactome.org/download/current/ReactomePathways.txt
#
# Output Files (in Dictionary directory):
#   KEGG_lst         - KEGG pathway IDs and names
#                      Format: pathway_id\tpathway_name
#   Reactome_lst     - Reactome pathway records
#                      Format: db_id\tstable_id\t\tPathway\tname\tdate\t...
#
# Usage:
#   perl update_pathways.pl [options]
#
# Options:
#   --dry-run     Show what would be done without writing files
#   --no-backup   Skip backup of old files
#   --dict-dir    Override dictionary directory path
#   --help        Show this help message
#
# Dependencies: LWP::UserAgent (core Perl + LWP)
#
# Author: SciMiner Dictionary Update System
# Date:   2026-03-15
# ==============================================================================

use strict;
use warnings;
use LWP::UserAgent;
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

# KEGG REST API for human pathways
my $KEGG_URL = 'https://rest.kegg.jp/list/pathway/hsa';

# Reactome pathways download
my $REACTOME_URL = 'https://reactome.org/download/current/ReactomePathways.txt';

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
Usage: perl update_pathways.pl [options]

Options:
  --dry-run     Show what would be done without writing files
  --no-backup   Skip backup of old files
  --dict-dir    Override dictionary directory path
  --help        Show this help message

Downloads fresh KEGG and Reactome pathway data and rebuilds the pathway
dictionary files for SciMiner.
USAGE
    exit 0;
}

# ==============================================================================
# Main
# ==============================================================================
print "=" x 60, "\n";
print "SciMiner Pathway Dictionary Update\n";
print "=" x 60, "\n";
print "Date:       ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";
print "Dict Dir:   $dict_dir\n";
print "Dry Run:    ", ($dry_run ? "YES" : "NO"), "\n";
print "-" x 60, "\n\n";

$dict_dir = abs_path($dict_dir) if -d $dict_dir;
unless (-d $dict_dir) {
    die "ERROR: Dictionary directory does not exist: $dict_dir\n";
}

# Backup existing files
if (!$no_backup && !$dry_run) {
    backup_pathway_files($dict_dir);
}

# Update KEGG
my $kegg_ok = update_kegg($dict_dir);

# Update Reactome
my $reactome_ok = update_reactome($dict_dir);

# Summary
print "\n";
print "=" x 60, "\n";
print "Summary:\n";
print "  KEGG update:     ", ($kegg_ok ? "SUCCESS" : "FAILED"), "\n";
print "  Reactome update: ", ($reactome_ok ? "SUCCESS" : "FAILED"), "\n";
print "=" x 60, "\n";

if ($dry_run) {
    print "\n*** DRY RUN - No files were written ***\n";
}

exit 0;


# ==============================================================================
# Subroutines
# ==============================================================================

sub backup_pathway_files {
    my ($dir) = @_;
    my $date_str = strftime("%Y%m%d_%H%M%S", localtime);
    my $backup_dir = "$dir/backup_$date_str";

    my @files = qw(KEGG_lst Reactome_lst);
    my $need_backup = 0;
    for my $f (@files) {
        $need_backup = 1 if -f "$dir/$f";
    }

    return unless $need_backup;

    make_path($backup_dir) unless -d $backup_dir;
    for my $f (@files) {
        if (-f "$dir/$f") {
            copy("$dir/$f", "$backup_dir/$f")
                or warn "WARNING: Could not backup $f: $!\n";
            print "[Backup] Backed up $f\n";
        }
    }
    print "\n";
}


sub update_kegg {
    my ($dir) = @_;

    print "[KEGG] Downloading human pathway list from KEGG REST API...\n";

    my $ua = LWP::UserAgent->new(
        timeout    => 120,
        agent      => 'SciMiner-DictionaryUpdate/1.0',
    );

    my $response = $ua->get($KEGG_URL);
    unless ($response->is_success) {
        warn "WARNING: Failed to download KEGG pathways: " . $response->status_line . "\n";
        warn "  Note: KEGG REST API may have usage restrictions.\n";
        warn "  If this continues to fail, you may need to download manually.\n";
        return 0;
    }

    my $raw_data = $response->content;
    printf "  Downloaded: %.2f KB\n", length($raw_data) / 1024;

    # Parse KEGG response format: "path:hsa00010\tGlycolysis / Gluconeogenesis - Homo sapiens (human)"
    my $outfile = "$dir/KEGG_lst";
    my $count = 0;

    if ($dry_run) {
        for my $line (split /\n/, $raw_data) {
            $line =~ s/\r//g;
            next unless $line =~ /\S/;
            $count++;
        }
        print "  [DRY RUN] Would write $count pathways to $outfile\n";
    } else {
        open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

        for my $line (split /\n/, $raw_data) {
            $line =~ s/\r//g;
            next unless $line =~ /\S/;

            # KEGG returns: "path:hsa00010\tGlycolysis / Gluconeogenesis - Homo sapiens (human)"
            # SciMiner expects: "hsa00010\tGlycolysis / Gluconeogenesis - Homo sapiens (human)"
            if ($line =~ /^path:(\S+)\t(.+)$/) {
                my $pathway_id   = $1;
                my $pathway_name = $2;
                print $fh "$pathway_id\t$pathway_name\n";
                $count++;
            } elsif ($line =~ /^(\S+)\t(.+)$/) {
                # Already in simple format
                print $fh "$1\t$2\n";
                $count++;
            }
        }

        close $fh;
    }

    print "  KEGG pathways: $count\n";
    return 1;
}


sub update_reactome {
    my ($dir) = @_;

    print "\n[Reactome] Downloading pathway data from Reactome...\n";

    my $ua = LWP::UserAgent->new(
        timeout    => 120,
        agent      => 'SciMiner-DictionaryUpdate/1.0',
        ssl_opts   => { verify_hostname => 0 },
    );

    my $response = $ua->get($REACTOME_URL);
    unless ($response->is_success) {
        warn "WARNING: Failed to download Reactome pathways: " . $response->status_line . "\n";
        return 0;
    }

    my $raw_data = $response->content;
    printf "  Downloaded: %.2f KB\n", length($raw_data) / 1024;

    # Reactome file format: "R-HSA-109581\tApoptosis\tHomo sapiens"
    # Original SciMiner Reactome_lst format (from the database dump):
    #   db_id\tstable_id\t\tPathway\tname\tdate\t...\tstable_identifier
    # We adapt to a compatible format
    my $outfile = "$dir/Reactome_lst";
    my $count = 0;
    my $human_count = 0;

    if ($dry_run) {
        for my $line (split /\n/, $raw_data) {
            $line =~ s/\r//g;
            next unless $line =~ /\S/;
            $count++;
            my @fields = split /\t/, $line;
            if (scalar(@fields) >= 3 && $fields[2] =~ /Homo sapiens/i) {
                $human_count++;
            }
        }
        print "  [DRY RUN] Would write $human_count human pathways (of $count total) to $outfile\n";
    } else {
        open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

        # Write in a format compatible with how the original code reads it
        # Original format: db_id\tstable_id\t\tPathway\tname\tdate\t...\tstable_identifier
        my $row_num = 0;
        for my $line (split /\n/, $raw_data) {
            $line =~ s/\r//g;
            next unless $line =~ /\S/;
            $count++;

            my @fields = split /\t/, $line, -1;
            next unless scalar(@fields) >= 3;

            # Filter for human pathways only
            next unless $fields[2] =~ /Homo sapiens/i;

            $row_num++;
            $human_count++;

            my $stable_id    = $fields[0];   # e.g., R-HSA-109581
            my $pathway_name = $fields[1];   # e.g., Apoptosis
            my $species      = $fields[2];   # e.g., Homo sapiens

            # Extract numeric part for db_id
            my $db_id = $stable_id;
            $db_id =~ s/^R-HSA-//;

            # Format matching original Reactome_lst structure:
            # db_id\tstable_id\t\tPathway\tname\tdate\t\t\trow_num\tStableIdentifier
            my $date_str = strftime("%Y-%m-%d %H:%M:%S", localtime);
            print $fh join("\t",
                $db_id,             # DB identifier
                $stable_id,         # Stable ID (e.g., GK_68616 -> now R-HSA-...)
                "\\N",              # null
                "Pathway",          # Type
                $pathway_name,      # Name
                $date_str,          # Date
                "\\N",              # null
                "\\N",              # null
                $row_num,           # Sequential number
                "StableIdentifier", # Identifier type
            ), "\n";
        }

        close $fh;
    }

    print "  Total pathways:        $count\n";
    print "  Human pathways:        $human_count\n";
    return 1;
}

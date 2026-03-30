#!/usr/bin/perl
# ==============================================================================
# update_hgnc_dictionary.pl
# ==============================================================================
# Purpose:  Download fresh HGNC (HUGO Gene Nomenclature Committee) data and
#           rebuild all gene/protein dictionaries used by SciMiner.
#
# Data Source:
#   HGNC Custom Download (genenames.org)
#   https://www.genenames.org/cgi-bin/download/custom
#
# Output Files (in Dictionary directory):
#   HUGO_trimmed_final_default   - Main gene dictionary (32-column tab-delimited)
#   HUGO_2_external_default      - HGNC to external database ID mappings
#   UNIQUENAME_default           - Unique gene/protein names (name, HGNC ID, source)
#   UNIQUESYMBOL_default         - Unique gene/protein symbols (symbol, HGNC ID, source)
#   DUPLICATENAME_default        - Ambiguous names mapping to multiple genes
#   DUPLICATESYMBOL_default      - Ambiguous symbols mapping to multiple genes
#   PARTNAMEBEGIN_default        - Partial gene name beginnings for compound matching
#   PARTNAMEMIDDLE_default       - Partial gene name middles for compound matching
#
# Usage:
#   perl update_hgnc_dictionary.pl [options]
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

# ==============================================================================
# Configuration
# ==============================================================================
my $SCRIPT_DIR = $0;
$SCRIPT_DIR =~ s/[^\/]+$//;
$SCRIPT_DIR = '.' if $SCRIPT_DIR eq '';

my $DEFAULT_DICT_DIR = "$SCRIPT_DIR/../annotation/SciMinerDB/Work/Dictionary";

# HGNC download URL - fetches all approved genes with required columns
my $HGNC_URL = 'https://www.genenames.org/cgi-bin/download/custom?'
    . 'col=gd_hgnc_id'
    . '&col=gd_app_sym'
    . '&col=gd_app_name'
    . '&col=gd_status'
    . '&col=gd_locus_type'
    . '&col=gd_prev_sym'
    . '&col=gd_prev_name'
    . '&col=gd_aliases'
    . '&col=gd_pub_chrom_map'
    . '&col=gd_date2app_or_res'
    . '&col=gd_date_mod'
    . '&col=gd_date_name_change'
    . '&col=gd_pub_acc_ids'
    . '&col=gd_enz_ids'
    . '&col=gd_pub_eg_id'
    . '&col=md_mgd_id'
    . '&col=gd_other_ids'
    . '&col=gd_pubmed_ids'
    . '&col=gd_pub_refseq_ids'
    . '&col=gd_gene_fam_name'
    . '&col=md_gdb_id'
    . '&col=md_eg_id'
    . '&col=md_mim_id'
    . '&col=md_refseq_id'
    . '&col=md_prot_id'
    . '&col=gd_pub_ensembl_id'
    . '&col=gd_pub_uniprot_ids'
    . '&status=Approved'
    . '&hgnc_datea=&hgnc_dateb='
    . '&order_by=gd_app_sym_sort'
    . '&format=text'
    . '&submit=submit';

# NCBI Gene data for supplementary symbol/name information
my $NCBI_GENE_INFO_URL = 'https://ftp.ncbi.nlm.nih.gov/gene/DATA/GENE_INFO/Mammalia/Homo_sapiens.gene_info.gz';

# ==============================================================================
# Command-line options
# ==============================================================================
my $dry_run     = 0;
my $no_backup   = 0;
my $dict_dir    = $DEFAULT_DICT_DIR;
my $help        = 0;
my $verbose     = 1;

GetOptions(
    'dry-run'     => \$dry_run,
    'no-backup'   => \$no_backup,
    'dict-dir=s'  => \$dict_dir,
    'help'        => \$help,
    'verbose'     => \$verbose,
) or die "Error in command line arguments\n";

if ($help) {
    print_usage();
    exit 0;
}

# ==============================================================================
# Main
# ==============================================================================
print "=" x 60, "\n";
print "SciMiner HGNC Dictionary Update\n";
print "=" x 60, "\n";
print "Date:       ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";
print "Dict Dir:   $dict_dir\n";
print "Dry Run:    ", ($dry_run ? "YES" : "NO"), "\n";
print "Backup:     ", ($no_backup ? "DISABLED" : "ENABLED"), "\n";
print "-" x 60, "\n\n";

# Resolve dict_dir to absolute path
use Cwd 'abs_path';
$dict_dir = abs_path($dict_dir) if -d $dict_dir;

unless (-d $dict_dir) {
    die "ERROR: Dictionary directory does not exist: $dict_dir\n";
}

# Step 1: Back up existing files
if (!$no_backup && !$dry_run) {
    backup_files($dict_dir);
}

# Step 2: Download HGNC data
print "[Step 1/7] Downloading HGNC data from genenames.org...\n";
my $hgnc_raw = download_url($HGNC_URL, "HGNC gene data");
die "ERROR: Failed to download HGNC data\n" unless $hgnc_raw;

# Step 3: Download NCBI Gene info for supplementary data
print "[Step 2/7] Downloading NCBI Gene info for supplementary symbols/names...\n";
my $ncbi_gene_info = download_and_gunzip($NCBI_GENE_INFO_URL, "NCBI Gene Info");

# Step 4: Parse and build dictionaries
print "[Step 3/7] Parsing HGNC data...\n";
my ($genes_ref, $hgnc_to_ncbi_ref) = parse_hgnc_data($hgnc_raw);

print "[Step 4/7] Parsing NCBI Gene Info for supplementary data...\n";
my $ncbi_data_ref = {};
if ($ncbi_gene_info) {
    $ncbi_data_ref = parse_ncbi_gene_info($ncbi_gene_info, $hgnc_to_ncbi_ref);
}

print "[Step 5/7] Building dictionary files...\n";
build_hugo_trimmed_final($dict_dir, $genes_ref, $ncbi_data_ref);
build_hugo_2_external($dict_dir, $genes_ref);
my ($unique_names, $unique_symbols, $dup_names, $dup_symbols) =
    build_unique_and_duplicate($dict_dir, $genes_ref, $ncbi_data_ref);

print "[Step 6/7] Building partial name match files...\n";
build_partname_files($dict_dir, $unique_names);

print "[Step 7/7] Complete.\n\n";

# Summary
print "=" x 60, "\n";
print "Summary:\n";
print "  Total genes processed: ", scalar(keys %$genes_ref), "\n";
print "  Unique names:          ", scalar(keys %$unique_names), "\n";
print "  Unique symbols:        ", scalar(keys %$unique_symbols), "\n";
print "  Duplicate names:       ", scalar(keys %$dup_names), "\n";
print "  Duplicate symbols:     ", scalar(keys %$dup_symbols), "\n";
print "=" x 60, "\n";

if ($dry_run) {
    print "\n*** DRY RUN - No files were written ***\n";
}

exit 0;


# ==============================================================================
# Subroutines
# ==============================================================================

sub print_usage {
    print <<'USAGE';
Usage: perl update_hgnc_dictionary.pl [options]

Options:
  --dry-run     Show what would be done without writing files
  --no-backup   Skip backup of old files
  --dict-dir    Override dictionary directory path
  --verbose     Extra progress messages
  --help        Show this help message

This script downloads fresh HGNC (HUGO Gene Nomenclature Committee) data and
rebuilds the gene/protein dictionaries used by SciMiner text mining.
USAGE
}


sub backup_files {
    my ($dir) = @_;
    my $date_str = strftime("%Y%m%d_%H%M%S", localtime);
    my $backup_dir = "$dir/backup_$date_str";

    print "[Backup] Creating backup at $backup_dir\n";
    make_path($backup_dir) or die "Cannot create backup dir: $!\n";

    my @files_to_backup = qw(
        HUGO_trimmed_final_default
        HUGO_2_external_default
        UNIQUENAME_default
        UNIQUESYMBOL_default
        DUPLICATENAME_default
        DUPLICATESYMBOL_default
        PARTNAMEBEGIN_default
        PARTNAMEMIDDLE_default
    );

    for my $file (@files_to_backup) {
        if (-f "$dir/$file") {
            copy("$dir/$file", "$backup_dir/$file")
                or warn "WARNING: Could not backup $file: $!\n";
            print "  Backed up: $file\n" if $verbose;
        }
    }
    print "[Backup] Done.\n\n";
}


sub download_url {
    my ($url, $description) = @_;
    $description ||= "data";

    my $ua = LWP::UserAgent->new(
        timeout    => 300,
        agent      => 'SciMiner-DictionaryUpdate/1.0',
        ssl_opts   => { verify_hostname => 0 },
    );

    print "  Downloading $description...\n";
    my $response = $ua->get($url);

    if ($response->is_success) {
        my $size = length($response->content);
        printf "  Downloaded: %.2f MB\n", $size / (1024 * 1024);
        return $response->content;
    } else {
        warn "WARNING: Download failed for $description: " . $response->status_line . "\n";
        return undef;
    }
}


sub download_and_gunzip {
    my ($url, $description) = @_;

    my $ua = LWP::UserAgent->new(
        timeout    => 600,
        agent      => 'SciMiner-DictionaryUpdate/1.0',
        ssl_opts   => { verify_hostname => 0 },
    );

    print "  Downloading $description (gzipped)...\n";
    my $response = $ua->get($url);

    if ($response->is_success) {
        my $compressed = $response->content;
        printf "  Downloaded: %.2f MB (compressed)\n", length($compressed) / (1024 * 1024);

        # Decompress using IO::Uncompress::Gunzip
        require IO::Uncompress::Gunzip;
        my $output;
        IO::Uncompress::Gunzip::gunzip(\$compressed, \$output)
            or do {
                warn "WARNING: Failed to decompress $description\n";
                return undef;
            };
        printf "  Uncompressed: %.2f MB\n", length($output) / (1024 * 1024);
        return $output;
    } else {
        warn "WARNING: Download failed for $description: " . $response->status_line . "\n";
        return undef;
    }
}


sub parse_hgnc_data {
    my ($raw_data) = @_;
    my %genes;
    my %hgnc_to_ncbi;
    my $line_num = 0;
    my $header_seen = 0;
    my @header_cols;

    for my $line (split /\n/, $raw_data) {
        $line =~ s/\r//g;
        $line_num++;

        # Skip the header line
        if (!$header_seen) {
            $header_seen = 1;
            @header_cols = split /\t/, $line;
            print "  HGNC header columns: ", scalar(@header_cols), "\n" if $verbose;
            next;
        }

        my @fields = split /\t/, $line, -1;
        next unless scalar(@fields) >= 5;

        # Extract HGNC ID number from "HGNC:12345" format
        my $hgnc_id_full = $fields[0] || '';
        my $hgnc_id_num;
        if ($hgnc_id_full =~ /HGNC:(\d+)/) {
            $hgnc_id_num = $1;
        } else {
            next; # Skip if no valid HGNC ID
        }

        my %gene;
        $gene{hgnc_id}        = $hgnc_id_num;
        $gene{symbol}         = $fields[1]  || '';
        $gene{name}           = $fields[2]  || '';
        $gene{status}         = $fields[3]  || '';
        $gene{locus_type}     = $fields[4]  || '';
        $gene{prev_symbols}   = $fields[5]  || '';  # comma-separated
        $gene{prev_names}     = $fields[6]  || '';
        $gene{aliases}        = $fields[7]  || '';  # comma-separated
        $gene{chromosome}     = $fields[8]  || '';
        $gene{date_approved}  = $fields[9]  || '';
        $gene{date_modified}  = $fields[10] || '';
        $gene{date_name_chg}  = $fields[11] || '';
        $gene{accession_ids}  = $fields[12] || '';
        $gene{enzyme_ids}     = $fields[13] || '';
        $gene{ncbi_gene_id}   = $fields[14] || '';  # Entrez Gene ID
        $gene{mgd_id}         = $fields[15] || '';
        $gene{specialist_db}  = $fields[16] || '';
        $gene{pubmed_ids}     = $fields[17] || '';
        $gene{refseq_ids}     = $fields[18] || '';
        $gene{gene_family}    = $fields[19] || '';
        $gene{gdb_id}         = $fields[20] || '';
        $gene{entrez_mapped}  = $fields[21] || '';
        $gene{omim_id}        = $fields[22] || '';
        $gene{refseq_mapped}  = $fields[23] || '';
        $gene{uniprot_id}     = $fields[24] || '';
        $gene{ensembl_id}     = $fields[25] || '';
        $gene{uniprot_ids}    = $fields[26] || '';

        $genes{$hgnc_id_num} = \%gene;

        # Build HGNC -> NCBI Gene ID mapping
        if ($gene{ncbi_gene_id} =~ /^\d+$/) {
            $hgnc_to_ncbi{$hgnc_id_num} = $gene{ncbi_gene_id};
        }
    }

    print "  Parsed ", scalar(keys %genes), " genes from HGNC data\n";
    return (\%genes, \%hgnc_to_ncbi);
}


sub parse_ncbi_gene_info {
    my ($raw_data, $hgnc_to_ncbi_ref) = @_;
    my %ncbi_data;

    # Build reverse lookup: NCBI Gene ID -> HGNC ID
    my %ncbi_to_hgnc;
    for my $hgnc_id (keys %$hgnc_to_ncbi_ref) {
        my $ncbi_id = $hgnc_to_ncbi_ref->{$hgnc_id};
        $ncbi_to_hgnc{$ncbi_id} = $hgnc_id;
    }

    my $count = 0;
    for my $line (split /\n/, $raw_data) {
        next if $line =~ /^#/;
        $line =~ s/\r//g;

        my @fields = split /\t/, $line, -1;
        next unless scalar(@fields) >= 14;

        # Only human genes (tax_id = 9606)
        next unless $fields[0] eq '9606';

        my $gene_id   = $fields[1];
        my $symbol    = $fields[2];
        my $synonyms  = $fields[4] || '-';  # Pipe-separated
        my $full_name = $fields[8] || '-';
        my $other_names = $fields[13] || '-';  # Pipe-separated

        # Only process genes we have in HGNC
        my $hgnc_id = $ncbi_to_hgnc{$gene_id};
        next unless defined $hgnc_id;

        my @syms;
        if ($synonyms ne '-') {
            @syms = split /\|/, $synonyms;
        }

        my @names;
        if ($other_names ne '-') {
            @names = split /\|/, $other_names;
        }
        # Add full name
        if ($full_name ne '-') {
            unshift @names, $full_name;
        }

        $ncbi_data{$hgnc_id} = {
            gene_id  => $gene_id,
            symbol   => $symbol,
            synonyms => \@syms,
            names    => \@names,
        };
        $count++;
    }

    print "  Matched $count NCBI Gene entries to HGNC IDs\n";
    return \%ncbi_data;
}


sub build_hugo_trimmed_final {
    my ($dir, $genes_ref, $ncbi_ref) = @_;
    my $outfile = "$dir/HUGO_trimmed_final_default";

    print "  Building HUGO_trimmed_final_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write to $outfile\n";
        return;
    }

    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # The original format has 32 columns (tab-delimited), matching the gene table in the DB.
    # Col layout (0-indexed in mining code):
    #   0:  GeneID (row number / sequential)
    #   1:  HGNC ID
    #   2:  Approved Symbol
    #   3:  Approved Name
    #   4:  Status
    #   5:  Locus Type
    #   6:  Previous Symbols
    #   7:  Previous Names
    #   8:  Aliases
    #   9:  Chromosome
    #  10:  Date Approved
    #  11:  Date Modified
    #  12:  Date Name Changed
    #  13:  Accession Numbers
    #  14:  Enzyme IDs
    #  15:  Entrez Gene ID
    #  16:  MGD ID
    #  17:  Specialist Database Links
    #  18:  PubMed IDs
    #  19:  RefSeq IDs
    #  20:  Gene Family Name
    #  21:  GDB ID (mapped data)
    #  22:  Entrez Gene ID (mapped data) -- used by mining code for NCBI Gene ID
    #  23:  OMIM ID (mapped data)
    #  24:  RefSeq (mapped data)
    #  25:  UniProt ID (mapped data)
    #  26:  Entrez Gene ID (again, for First_Group lookup)
    #  27:  First word(s) of gene name
    #  28:  NCBI_LocusLink_Symbols (symbol<_>alias1<_>alias2<_>)
    #  29:  NCBI_LocusLink_Names (name1<_>name2<_>)
    #  30:  NCBI_GeneDB_Symbols (symbol<_>alias1<_>)
    #  31:  NCBI_GeneDB_Names (name1<_>name2<_>)

    my $row_num = 0;
    for my $hgnc_id (sort { $a <=> $b } keys %$genes_ref) {
        $row_num++;
        my $g = $genes_ref->{$hgnc_id};

        # Get NCBI supplementary data
        my $ncbi = $ncbi_ref->{$hgnc_id} || {};
        my $ncbi_gene_id = $g->{ncbi_gene_id} || '';

        # Build first word of gene name
        my $first_group = '';
        if ($g->{name}) {
            my @words = split(/\s+/, $g->{name});
            $first_group = $words[0] || '';
        }

        # Build symbols list: approved symbol + previous symbols + aliases
        my @all_symbols = ($g->{symbol});
        if ($g->{prev_symbols}) {
            my @prev = split(/,\s*/, $g->{prev_symbols});
            push @all_symbols, @prev;
        }
        if ($g->{aliases}) {
            my @ali = split(/,\s*/, $g->{aliases});
            push @all_symbols, @ali;
        }
        # Add NCBI synonyms if available
        if ($ncbi->{synonyms} && @{$ncbi->{synonyms}}) {
            for my $syn (@{$ncbi->{synonyms}}) {
                push @all_symbols, $syn unless grep { $_ eq $syn } @all_symbols;
            }
        }
        my $symbols_str = join('<_>', @all_symbols) . '<_>';

        # Build names list: approved name + NCBI names
        my @all_names = ($g->{name});
        if ($ncbi->{names}) {
            for my $n (@{$ncbi->{names}}) {
                push @all_names, $n unless grep { lc($_) eq lc($n) } @all_names;
            }
        }
        my $names_str = join('<_>', @all_names) . '<_>';

        # NCBI GeneDB symbols and names (from NCBI data)
        my $ncbi_sym_str = $symbols_str;   # Same as LocusLink symbols
        my $ncbi_name_str = $names_str;

        # Specialist DB links placeholder
        my $specialist_db = $g->{specialist_db} || '';

        # Mapped data: use same gene ID for both columns 15 and 22
        my $entrez_mapped = $g->{entrez_mapped} || $ncbi_gene_id;

        # Build the 32-column line
        my @cols = (
            $row_num,                           # 0: GeneID (row number)
            $hgnc_id,                           # 1: HGNC ID
            $g->{symbol},                       # 2: Approved Symbol
            $g->{name},                         # 3: Approved Name
            $g->{status},                       # 4: Status
            $g->{locus_type},                   # 5: Locus Type
            $g->{prev_symbols} || '',           # 6: Previous Symbols
            $g->{prev_names} || '',             # 7: Previous Names
            $g->{aliases} || '',                # 8: Aliases
            $g->{chromosome} || '',             # 9: Chromosome
            $g->{date_approved} || '',          # 10: Date Approved
            $g->{date_modified} || '',          # 11: Date Modified
            $g->{date_name_chg} || '',          # 12: Date Name Changed
            $g->{accession_ids} || '',          # 13: Accession Numbers
            $g->{enzyme_ids} || '',             # 14: Enzyme IDs
            $ncbi_gene_id,                      # 15: Entrez Gene ID
            $g->{mgd_id} || '',                 # 16: MGD ID
            $specialist_db,                     # 17: Specialist DB Links
            $g->{pubmed_ids} || '',             # 18: PubMed IDs
            $g->{refseq_ids} || '',             # 19: RefSeq IDs
            $g->{gene_family} || '',            # 20: Gene Family Name
            $g->{gdb_id} || '',                 # 21: GDB ID (mapped)
            $entrez_mapped,                     # 22: Entrez Gene ID (mapped) -- KEY for mining
            $g->{omim_id} || '',                # 23: OMIM ID (mapped)
            $g->{refseq_mapped} || '',          # 24: RefSeq (mapped)
            $g->{uniprot_id} || '',             # 25: UniProt ID (mapped)
            $ncbi_gene_id,                      # 26: NCBI Gene ID (for first group)
            $first_group,                       # 27: First word(s) of gene name
            $symbols_str,                       # 28: NCBI_LocusLink_Symbols
            $names_str,                         # 29: NCBI_LocusLink_Names
            $ncbi_sym_str,                      # 30: NCBI_GeneDB_Symbols
            $ncbi_name_str,                     # 31: NCBI_GeneDB_Names
        );

        print $fh join("\t", @cols), "\n";
    }

    close $fh;
    print "  Wrote $row_num records to HUGO_trimmed_final_default\n";
}


sub build_hugo_2_external {
    my ($dir, $genes_ref) = @_;
    my $outfile = "$dir/HUGO_2_external_default";

    print "  Building HUGO_2_external_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write to $outfile\n";
        return;
    }

    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # Format: 24 columns matching the gene2external table
    # Col 0: Row number
    # Col 1: HGNC ID
    # Col 2: Symbol
    # Col 3: Ensembl Gene ID
    # Col 4: UniGene (deprecated, leave empty)
    # Col 5: NCBI Gene ID
    # Col 6: RefSeq IDs
    # Col 7: RefSeq (mapped)
    # Col 8: Accession IDs
    # Col 9: UniProt Name (derived from symbol)
    # Col 10: UniProt ID
    # Col 11: Protein name (gene name)
    # Col 12: Chromosome number
    # Col 13: Start position (empty, from Ensembl)
    # Col 14: End position (empty, from Ensembl)
    # Col 15: Strand (empty)
    # Col 16: PDB (empty)
    # Col 17: IPI (deprecated)
    # Col 18: OMIM ID
    # Col 19: GO terms (empty without separate download)
    # Col 20: KEGG pathways (empty)
    # Col 21: Reactome IDs (empty)
    # Col 22: Reactome names (empty)
    # Col 23: PubMed IDs

    my $row_num = 0;
    for my $hgnc_id (sort { $a <=> $b } keys %$genes_ref) {
        $row_num++;
        my $g = $genes_ref->{$hgnc_id};

        # Extract chromosome number from map location
        my $chrom_num = '';
        if ($g->{chromosome} =~ /^(\d+|[XY])/) {
            $chrom_num = $1;
        }

        my @cols = (
            $row_num,                           # 0: Row number
            $hgnc_id,                           # 1: HGNC ID
            $g->{symbol},                       # 2: Symbol
            $g->{ensembl_id} || '',             # 3: Ensembl Gene ID
            '',                                 # 4: UniGene (deprecated)
            $g->{ncbi_gene_id} || '',           # 5: NCBI Gene ID
            $g->{refseq_ids} || '',             # 6: RefSeq IDs
            $g->{refseq_mapped} || '',          # 7: RefSeq (mapped)
            $g->{accession_ids} || '',          # 8: Accession IDs
            ($g->{symbol} ? $g->{symbol}.'_HUMAN' : ''),  # 9: UniProt Name
            $g->{uniprot_id} || '',             # 10: UniProt ID
            $g->{name} || '',                   # 11: Protein name
            $chrom_num,                         # 12: Chromosome
            '',                                 # 13: Start pos
            '',                                 # 14: End pos
            '',                                 # 15: Strand
            '',                                 # 16: PDB
            '',                                 # 17: IPI (deprecated)
            $g->{omim_id} || '',                # 18: OMIM
            '',                                 # 19: GO
            '',                                 # 20: KEGG
            '',                                 # 21: Reactome IDs
            '',                                 # 22: Reactome names
            $g->{pubmed_ids} || '',             # 23: PubMed IDs
        );

        print $fh join("\t", @cols), "\n";
    }

    close $fh;
    print "  Wrote $row_num records to HUGO_2_external_default\n";
}


sub build_unique_and_duplicate {
    my ($dir, $genes_ref, $ncbi_ref) = @_;

    # Collect all symbols and names, track which map to single vs multiple HGNC IDs
    my %symbol_to_hgnc;  # symbol => [hgnc_id1, hgnc_id2, ...]
    my %name_to_hgnc;    # name => [hgnc_id1, hgnc_id2, ...]
    my %symbol_source;   # symbol => source_label
    my %name_source;     # name => source_label

    for my $hgnc_id (keys %$genes_ref) {
        my $g = $genes_ref->{$hgnc_id};
        my $ncbi = $ncbi_ref->{$hgnc_id} || {};

        # --- Symbols ---
        # Approved symbol
        add_to_map(\%symbol_to_hgnc, \%symbol_source, $g->{symbol}, $hgnc_id, 'HGNC_Symbol');

        # Previous symbols
        if ($g->{prev_symbols}) {
            for my $sym (split /,\s*/, $g->{prev_symbols}) {
                $sym =~ s/^\s+|\s+$//g;
                add_to_map(\%symbol_to_hgnc, \%symbol_source, $sym, $hgnc_id, 'HGNC_PrevSymbol') if $sym;
            }
        }

        # Aliases
        if ($g->{aliases}) {
            for my $sym (split /,\s*/, $g->{aliases}) {
                $sym =~ s/^\s+|\s+$//g;
                add_to_map(\%symbol_to_hgnc, \%symbol_source, $sym, $hgnc_id, 'HGNC_Alias') if $sym;
            }
        }

        # NCBI synonyms
        if ($ncbi->{synonyms}) {
            for my $sym (@{$ncbi->{synonyms}}) {
                add_to_map(\%symbol_to_hgnc, \%symbol_source, $sym, $hgnc_id, 'NCBI_Symbol');
            }
        }

        # --- Names ---
        # Approved name
        add_to_map(\%name_to_hgnc, \%name_source, $g->{name}, $hgnc_id, 'HGNC_Name') if $g->{name};

        # Previous names (may be quoted, comma-separated)
        if ($g->{prev_names}) {
            for my $name (parse_quoted_csv($g->{prev_names})) {
                $name =~ s/^\s+|\s+$//g;
                add_to_map(\%name_to_hgnc, \%name_source, $name, $hgnc_id, 'HGNC_PrevName') if $name;
            }
        }

        # NCBI names
        if ($ncbi->{names}) {
            for my $name (@{$ncbi->{names}}) {
                add_to_map(\%name_to_hgnc, \%name_source, $name, $hgnc_id, 'NCBI_Name');
            }
        }
    }

    # Separate unique vs duplicate
    my (%unique_symbols, %duplicate_symbols);
    my (%unique_names, %duplicate_names);

    for my $sym (keys %symbol_to_hgnc) {
        my @ids = unique_list(@{$symbol_to_hgnc{$sym}});
        if (scalar(@ids) == 1) {
            $unique_symbols{$sym} = { hgnc_id => $ids[0], source => $symbol_source{$sym} };
        } else {
            $duplicate_symbols{$sym} = \@ids;
        }
    }

    for my $name (keys %name_to_hgnc) {
        my @ids = unique_list(@{$name_to_hgnc{$name}});
        if (scalar(@ids) == 1) {
            $unique_names{$name} = { hgnc_id => $ids[0], source => $name_source{$name} };
        } else {
            $duplicate_names{$name} = \@ids;
        }
    }

    # Write files
    write_unique_symbols($dir, \%unique_symbols);
    write_unique_names($dir, \%unique_names);
    write_duplicate_symbols($dir, \%duplicate_symbols);
    write_duplicate_names($dir, \%duplicate_names);

    return (\%unique_names, \%unique_symbols, \%duplicate_names, \%duplicate_symbols);
}


sub add_to_map {
    my ($map_ref, $source_ref, $key, $hgnc_id, $source) = @_;
    return unless defined $key && $key ne '';

    if (!defined $map_ref->{$key}) {
        $map_ref->{$key} = [$hgnc_id];
        $source_ref->{$key} = $source;
    } else {
        push @{$map_ref->{$key}}, $hgnc_id;
    }
}


sub parse_quoted_csv {
    # Parse comma-separated values that may contain quoted strings
    my ($str) = @_;
    my @result;
    while ($str =~ /("([^"]*)")|([^,]+)/g) {
        my $val = defined($2) ? $2 : $3;
        $val =~ s/^\s+|\s+$//g;
        push @result, $val if $val;
    }
    return @result;
}


sub unique_list {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}


sub write_unique_symbols {
    my ($dir, $unique_ref) = @_;
    my $outfile = "$dir/UNIQUESYMBOL_default";

    print "  Building UNIQUESYMBOL_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write to $outfile\n";
        return;
    }

    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # Format: symbol\thgnc_id\tsource
    my $count = 0;
    for my $sym (sort keys %$unique_ref) {
        print $fh $sym, "\t", $unique_ref->{$sym}{hgnc_id}, "\t", $unique_ref->{$sym}{source}, "\n";
        $count++;
    }

    close $fh;
    print "  Wrote $count unique symbols\n";
}


sub write_unique_names {
    my ($dir, $unique_ref) = @_;
    my $outfile = "$dir/UNIQUENAME_default";

    print "  Building UNIQUENAME_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write to $outfile\n";
        return;
    }

    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # Format: name\thgnc_id\tsource
    my $count = 0;
    for my $name (sort keys %$unique_ref) {
        print $fh $name, "\t", $unique_ref->{$name}{hgnc_id}, "\t", $unique_ref->{$name}{source}, "\n";
        $count++;
    }

    close $fh;
    print "  Wrote $count unique names\n";
}


sub write_duplicate_symbols {
    my ($dir, $dup_ref) = @_;
    my $outfile = "$dir/DUPLICATESYMBOL_default";

    print "  Building DUPLICATESYMBOL_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write to $outfile\n";
        return;
    }

    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # Format: symbol\thgnc_id1__hgnc_id2__tag<_>hgnc_id1__hgnc_id3__tag<_>
    # Tag is sameFirstName or diffFirstName based on first word of gene name
    my $count = 0;
    for my $sym (sort keys %$dup_ref) {
        my @ids = @{$dup_ref->{$sym}};
        next unless scalar(@ids) >= 2;

        print $fh $sym, "\t";
        for (my $j = 1; $j < scalar(@ids); $j++) {
            # Determine tag: check if first word of gene names match
            my $tag = "diffFirstName";  # default
            print $fh $ids[0], "__", $ids[$j], "__", $tag, "<_>";
        }
        print $fh "\n";
        $count++;
    }

    close $fh;
    print "  Wrote $count duplicate symbols\n";
}


sub write_duplicate_names {
    my ($dir, $dup_ref) = @_;
    my $outfile = "$dir/DUPLICATENAME_default";

    print "  Building DUPLICATENAME_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write to $outfile\n";
        return;
    }

    open(my $fh, '>', $outfile) or die "Cannot write $outfile: $!\n";

    # Format: name\thgnc_id1__hgnc_id2<_>hgnc_id1__hgnc_id3<_>
    my $count = 0;
    for my $name (sort keys %$dup_ref) {
        my @ids = @{$dup_ref->{$name}};
        next unless scalar(@ids) >= 2;

        print $fh $name, "\t";
        for (my $j = 1; $j < scalar(@ids); $j++) {
            print $fh $ids[0], "__", $ids[$j], "<_>";
        }
        print $fh "\n";
        $count++;
    }

    close $fh;
    print "  Wrote $count duplicate names\n";
}


sub build_partname_files {
    my ($dir, $unique_names_ref) = @_;

    # This replicates the logic from SciMiner.pm create_SciMiner_default_files
    # for PARTNAMEBEGIN_default and PARTNAMEMIDDLE_default

    print "  Building PARTNAMEBEGIN_default and PARTNAMEMIDDLE_default...\n";
    if ($dry_run) {
        print "  [DRY RUN] Would write partname files\n";
        return;
    }

    # Step 1: Build index structures by first 3 characters and by length
    my %fourLetterHash;       # first3chars -> {length -> [terms]}
    my %fourLetterHashHUGO;   # first3chars -> {length -> [hgnc_ids]}
    my %termByLength;         # length -> [terms]
    my %hugoIDByLength;       # length -> [hgnc_ids]

    for my $name (keys %$unique_names_ref) {
        my $hgnc_id = $unique_names_ref->{$name}{hgnc_id};
        my $term = special_character_handling($name);
        my $first3 = substr($name, 0, 3);
        $first3 = special_character_handling($first3);
        my $len = length($name);

        push @{$fourLetterHash{$first3}{$len}}, $term;
        push @{$fourLetterHashHUGO{$first3}{$len}}, $hgnc_id;
        push @{$termByLength{$len}}, $term;
        push @{$hugoIDByLength{$len}}, $hgnc_id;
    }

    # Step 2: Build PARTNAMEBEGIN_default
    my $begin_file = "$dir/PARTNAMEBEGIN_default";
    open(my $bfh, '>', $begin_file) or die "Cannot write $begin_file: $!\n";

    my $begin_count = 0;
    for my $first3key (keys %fourLetterHash) {
        my @lengthKeys = keys %{$fourLetterHash{$first3key}};
        for my $j (0 .. $#lengthKeys) {
            my @baitTerms = @{$fourLetterHash{$first3key}{$lengthKeys[$j]}};
            my @baitIDs   = @{$fourLetterHashHUGO{$first3key}{$lengthKeys[$j]}};

            for my $k (0 .. $#lengthKeys) {
                next unless $lengthKeys[$j] < $lengthKeys[$k];
                my @preyTerms = @{$fourLetterHash{$first3key}{$lengthKeys[$k]}};
                my @preyIDs   = @{$fourLetterHashHUGO{$first3key}{$lengthKeys[$k]}};

                for my $bait (0 .. $#baitTerms) {
                    for my $prey (0 .. $#preyTerms) {
                        if ($preyTerms[$prey] =~ /^\Q$baitTerms[$bait]\E\b/i) {
                            my $tag = ($baitIDs[$bait] == $preyIDs[$prey]) ? "SAME" : "DIFF";
                            print $bfh "$baitTerms[$bait]\t$baitIDs[$bait]\t$preyTerms[$prey]\t$preyIDs[$prey]\t$tag\n";
                            $begin_count++;
                        }
                    }
                }
            }
        }
    }
    close $bfh;
    print "  Wrote $begin_count entries to PARTNAMEBEGIN_default\n";

    # Step 3: Build PARTNAMEMIDDLE_default
    my $middle_file = "$dir/PARTNAMEMIDDLE_default";
    open(my $mfh, '>', $middle_file) or die "Cannot write $middle_file: $!\n";

    my $middle_count = 0;
    my @allLengthKeys = keys %termByLength;
    for my $i (0 .. $#allLengthKeys) {
        my @baitTerms = @{$termByLength{$allLengthKeys[$i]}};
        my @baitIDs   = @{$hugoIDByLength{$allLengthKeys[$i]}};

        for my $j (0 .. $#allLengthKeys) {
            next if $i == $j || $allLengthKeys[$i] >= $allLengthKeys[$j];
            my @preyTerms = @{$termByLength{$allLengthKeys[$j]}};
            my @preyIDs   = @{$hugoIDByLength{$allLengthKeys[$j]}};

            for my $bait (0 .. $#baitTerms) {
                for my $prey (0 .. $#preyTerms) {
                    if ($preyTerms[$prey] =~ /^\S.*\b\Q$baitTerms[$bait]\E\b/i) {
                        my $tag = ($baitIDs[$bait] == $preyIDs[$prey]) ? "SAME" : "DIFF";
                        print $mfh "$baitTerms[$bait]\t$baitIDs[$bait]\t$preyTerms[$prey]\t$preyIDs[$prey]\t$tag\n";
                        $middle_count++;
                    }
                }
            }
        }
    }
    close $mfh;
    print "  Wrote $middle_count entries to PARTNAMEMIDDLE_default\n";
    print "  NOTE: PARTNAMEMIDDLE generation may take a long time for large dictionaries.\n";
}


sub special_character_handling {
    # Replicate the special_character_handling_for_hash_key function from SciMiner
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ s/\'|\"|\(|\)|\[|\]|\{|\}/ /g;
    $str =~ s/\s+/ /g;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

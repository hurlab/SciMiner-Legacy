#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                generateNetworkJSON.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#
#  Created       : 2026-03-15
#  Desc:  This CGI reads the merged summary file and generates a JSON file
#         containing gene nodes and co-occurrence edges for the Cytoscape.js
#         network viewer. Replaces the defunct Java MiMI network viewer.
#
#  Data format of merged summary file (tab-separated):
#    Col 0: Symbol (gene symbol, e.g., BRCA1)
#    Col 1: HUGOID (HGNC ID, e.g., 672)
#    Col 2: Name (full gene name)
#    Col 3: #Occur (occurrence count in text)
#    Col 4: #Paper (number of papers mentioning this gene)
#    Col 5: MatchString (matched terms separated by |)
#    Col 6: PMIDs (comma-separated PubMed IDs)
#
#******************************************************************************
BEGIN {
push (@INC, "/home/sciminer/legacy/annotation/SciMinerDB/Modules/");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;
use Annotation::SciMiner;
use CGI qw(:standard);
#use warnings;
use strict;

# ----------------------------------------------------------------------------
#  Load working environment for ANNOTATION
# ----------------------------------------------------------------------------
my %annoENV = anno_environmental_file_open ( );

#------------------------------------------------------------------------------
#  Initialize CGI and get parameters
#------------------------------------------------------------------------------
my $query = new CGI;

my $MinPaperMethod  = param("MinPaperMethod");
my $MinTopPaper     = param("MinTopPaper");
my $RelPath         = param("RelPath");
my $MerSumFileName  = param("MerSumFileName");
my $TotalPMID       = param("TotalPMID");
my $RandomNumber    = param("RandomNumber");

my @errorMessage = ();

#------------------------------------------------------------------------------
#  Data structures for gene information
#------------------------------------------------------------------------------
my %hugoID2Symbol   = ();
my %hugoSymbol2ID   = ();
my %hugoID2Name     = ();
my @hugoIDs         = ();
my $hugoIDCnt       = 0;
my $hugoIDCntTotal  = 0;
my %hugoID2Occur    = ();
my %hugoID2Paper    = ();
my %hugoID2PMIDs    = ();
my %hugoID2Match    = ();
my $MinTopCheck     = 'true';


#------------------------------------------------------------------------------
#  Load and parse the merged summary file
#------------------------------------------------------------------------------
if ( ((defined $MinPaperMethod) && ($MinPaperMethod ne "")) &&
     ((defined $MinTopPaper) && ($MinTopPaper ne "")) &&
     ((defined $RelPath) && ($RelPath ne "")) &&
     ((defined $MerSumFileName) && ($MerSumFileName ne "")) &&
     ((defined $TotalPMID) && ($TotalPMID ne "")))
{
    load_summary_with_pmids(
        $RelPath . $MerSumFileName,
        \%hugoID2Symbol, \%hugoSymbol2ID, \%hugoID2Name,
        \@hugoIDs, \$hugoIDCnt, \$hugoIDCntTotal,
        \%hugoID2Occur, \%hugoID2Paper, \%hugoID2PMIDs, \%hugoID2Match,
        $MinTopCheck, $TotalPMID, $MinTopPaper, $MinPaperMethod
    );
} else {
    push @errorMessage, "Missing required parameters";
}

#------------------------------------------------------------------------------
#  Generate JSON and save to temp file
#------------------------------------------------------------------------------
if ($hugoIDCnt < 1) {
    push @errorMessage, "No gene targets found matching criteria";
}

if (defined $errorMessage[0]) {
    # Output error as JSON
    print $query->header(-type => 'text/html', -charset => 'utf-8');
    print $query->start_html(-title => 'Network Generation Error');
    print "<h2 style='color:red;'>Error generating network</h2>";
    for (my $i = 0; $i < scalar @errorMessage; $i++) {
        print "<p>Error " . ($i+1) . ": $errorMessage[$i]</p>";
    }
    print $query->end_html;
    exit;
}

# Build JSON
my $json = build_network_json(
    \@hugoIDs, \%hugoID2Symbol, \%hugoID2Name,
    \%hugoID2Occur, \%hugoID2Paper, \%hugoID2PMIDs, \%hugoID2Match
);

# Save JSON to temp file
my $tempDir = $RelPath . 'Temp/';
if (! -d $tempDir) {
    mkdir $tempDir;
}
my $jsonFileName = $RandomNumber . '.json';
my $jsonFilePath = $tempDir . $jsonFileName;

open(my $fh, '>', $jsonFilePath) or do {
    print $query->header(-type => 'text/html', -charset => 'utf-8');
    print $query->start_html(-title => 'Network Generation Error');
    print "<h2 style='color:red;'>Error: Cannot write JSON file</h2>";
    print "<p>$jsonFilePath: $!</p>";
    print $query->end_html;
    exit;
};
print $fh $json;
close $fh;

#------------------------------------------------------------------------------
#  Redirect to network viewer
#------------------------------------------------------------------------------
my $my_url = $query->self_url;
my @tmpSplit1 = split(/\/\//, $my_url);
my @tmpSplit2 = split(/\//, $tmpSplit1[1]);
my $hostURL = $tmpSplit2[0];
my $protocol = ($my_url =~ /^https/) ? 'https' : 'http';

my $jsonURL = $protocol . '://' . $hostURL . '/SciMiner/' . $RelPath . 'Temp/' . $jsonFileName;
my $viewerURL = $protocol . '://' . $hostURL . '/SciMiner/network_viewer.html?data=' . $jsonURL;

print $query->redirect($viewerURL);

exit;


#==============================================================================
#  Subroutines
#==============================================================================

# Load the merged summary file including PMIDs (column 6) and match strings (column 5)
# Applies the same filtering logic as the original generateNetwork.cgi
sub load_summary_with_pmids {
    my $fileName            = shift;
    my $hugoID2SymbolRef    = shift;
    my $hugoSymbol2IDRef    = shift;
    my $hugoID2NameRef      = shift;
    my $hugoIDsRef          = shift;
    my $hugoIDCntRef        = shift;
    my $hugoIDCntTotalRef   = shift;
    my $hugoID2OccurRef     = shift;
    my $hugoID2PaperRef     = shift;
    my $hugoID2PMIDsRef     = shift;
    my $hugoID2MatchRef     = shift;
    my $MinTopCheck         = shift;
    my $TotalPMID           = shift;
    my $minTopPaper         = shift;
    my $minTopMethod        = shift;

    $$hugoIDCntTotalRef = 0;

    if (! -f $fileName) {
        return;
    }

    # Read all data first
    my @allLines = ();
    open(FILENAME, $fileName) || return;
    while (<FILENAME>) {
        my $line = $_;
        $line =~ s/\r|\n//g;
        next if ($line =~ /^#/);  # Skip header lines
        next if ($line eq "");
        push @allLines, $line;
    }
    close FILENAME;

    $$hugoIDCntTotalRef = scalar @allLines;

    # Determine threshold
    if (($MinTopCheck eq 'false') || (not defined $MinTopCheck)) {
        # No filtering, load everything
        foreach my $line (@allLines) {
            my @tmp = split(/\t/, $line);
            _add_gene_data(\@tmp, $hugoID2SymbolRef, $hugoSymbol2IDRef,
                           $hugoID2NameRef, $hugoIDsRef, $hugoID2OccurRef,
                           $hugoID2PaperRef, $hugoID2PMIDsRef, $hugoID2MatchRef);
        }
    } else {
        if ((not defined $minTopPaper) || ($minTopPaper eq "")) {
            $minTopPaper = 1;
        }
        if ((not defined $minTopMethod) || ($minTopMethod eq "")) {
            $minTopMethod = 'MinPaperCount';
        }

        if (($minTopMethod eq 'MinPaperCount') || ($minTopMethod eq 'MinPaperPercentage')) {
            my $tmpThreshold = $minTopPaper;
            if ($minTopMethod eq 'MinPaperPercentage') {
                $tmpThreshold = $TotalPMID * $minTopPaper / 100;
            }

            foreach my $line (@allLines) {
                my @tmp = split(/\t/, $line);
                if (defined $tmp[4] && $tmp[4] >= $tmpThreshold) {
                    _add_gene_data(\@tmp, $hugoID2SymbolRef, $hugoSymbol2IDRef,
                                   $hugoID2NameRef, $hugoIDsRef, $hugoID2OccurRef,
                                   $hugoID2PaperRef, $hugoID2PMIDsRef, $hugoID2MatchRef);
                }
            }
        } else {
            # TopPaperCount or TopPaperPercentage - sort first
            my %symbol2data = ();
            my @symbols = ();
            foreach my $line (@allLines) {
                my @tmp = split(/\t/, $line);
                $symbol2data{$tmp[0]} = \@tmp;
                push @symbols, $tmp[0];
            }

            # Sort by paper count desc, then occurrence desc
            my @sorted = sort {
                ($symbol2data{$b}->[4] || 0) <=> ($symbol2data{$a}->[4] || 0) ||
                ($symbol2data{$b}->[3] || 0) <=> ($symbol2data{$a}->[3] || 0)
            } @symbols;

            my $tmpThreshold = $minTopPaper;
            if ($minTopMethod eq 'TopPaperCount') {
                if ($minTopPaper > scalar @sorted) {
                    $tmpThreshold = scalar @sorted;
                }
            } elsif ($minTopMethod eq 'TopPaperPercentage') {
                $tmpThreshold = int((scalar @sorted) * $minTopPaper / 100);
            }

            for (my $i = 0; $i < $tmpThreshold && $i < scalar @sorted; $i++) {
                my $sym = $sorted[$i];
                my @tmp = @{$symbol2data{$sym}};
                _add_gene_data(\@tmp, $hugoID2SymbolRef, $hugoSymbol2IDRef,
                               $hugoID2NameRef, $hugoIDsRef, $hugoID2OccurRef,
                               $hugoID2PaperRef, $hugoID2PMIDsRef, $hugoID2MatchRef);
            }
        }
    }

    $$hugoIDCntRef = scalar @{$hugoIDsRef};
}


# Helper to add gene data from a parsed line
sub _add_gene_data {
    my $tmpRef              = shift;
    my $hugoID2SymbolRef    = shift;
    my $hugoSymbol2IDRef    = shift;
    my $hugoID2NameRef      = shift;
    my $hugoIDsRef          = shift;
    my $hugoID2OccurRef     = shift;
    my $hugoID2PaperRef     = shift;
    my $hugoID2PMIDsRef     = shift;
    my $hugoID2MatchRef     = shift;

    my @tmp = @{$tmpRef};
    my $symbol  = $tmp[0] || '';
    my $hugoID  = $tmp[1] || '';
    my $name    = $tmp[2] || '';
    my $occur   = $tmp[3] || 0;
    my $papers  = $tmp[4] || 0;
    my $match   = $tmp[5] || '';
    my $pmids   = $tmp[6] || '';

    return if ($hugoID eq '' || $symbol eq '');

    push @{$hugoIDsRef}, $hugoID;

    if (not defined $$hugoID2SymbolRef{$hugoID}) {
        $$hugoID2SymbolRef{$hugoID} = $symbol;
    }
    if (not defined $$hugoSymbol2IDRef{$symbol}) {
        $$hugoSymbol2IDRef{$symbol} = $hugoID;
    }
    if (not defined $$hugoID2NameRef{$hugoID}) {
        $$hugoID2NameRef{$hugoID} = $name;
    }
    $$hugoID2OccurRef{$hugoID} = $occur;
    $$hugoID2PaperRef{$hugoID} = $papers;
    $$hugoID2PMIDsRef{$hugoID} = $pmids;
    $$hugoID2MatchRef{$hugoID} = $match;
}


# Build JSON string for Cytoscape.js from the gene data
sub build_network_json {
    my $hugoIDsRef      = shift;
    my $hugoID2SymbolRef = shift;
    my $hugoID2NameRef  = shift;
    my $hugoID2OccurRef = shift;
    my $hugoID2PaperRef = shift;
    my $hugoID2PMIDsRef = shift;
    my $hugoID2MatchRef = shift;

    my @nodeJsonParts = ();
    my @edgeJsonParts = ();

    # Build PMID-to-gene index for co-occurrence edge computation
    my %pmid2genes = ();
    my %uniqueIDs = ();

    foreach my $hid (@{$hugoIDsRef}) {
        next if (defined $uniqueIDs{$hid});
        $uniqueIDs{$hid} = 1;

        my $pmidStr = $$hugoID2PMIDsRef{$hid} || '';
        $pmidStr =~ s/\s+//g;
        my @pmids = split(/,/, $pmidStr);

        foreach my $pmid (@pmids) {
            next if ($pmid eq '');
            if (not defined $pmid2genes{$pmid}) {
                $pmid2genes{$pmid} = [];
            }
            push @{$pmid2genes{$pmid}}, $hid;
        }
    }

    # Build co-occurrence edges from shared PMIDs
    my %edgePairs = ();  # "geneA\tgeneB" -> { count => N, pmids => "..." }

    foreach my $pmid (keys %pmid2genes) {
        my @genes = @{$pmid2genes{$pmid}};
        next if (scalar @genes < 2);

        # For large paper gene lists (>50 genes), limit to avoid combinatorial explosion
        my $limit = (scalar @genes > 50) ? 50 : scalar @genes;

        for (my $i = 0; $i < $limit; $i++) {
            for (my $j = $i + 1; $j < $limit; $j++) {
                my ($ga, $gb) = sort ($genes[$i], $genes[$j]);
                my $key = "$ga\t$gb";
                if (not defined $edgePairs{$key}) {
                    $edgePairs{$key} = { count => 0, pmids => [] };
                }
                $edgePairs{$key}->{count}++;
                if (scalar @{$edgePairs{$key}->{pmids}} < 10) {
                    push @{$edgePairs{$key}->{pmids}}, $pmid;
                }
            }
        }
    }

    # Build node JSON
    foreach my $hid (keys %uniqueIDs) {
        my $symbol  = $$hugoID2SymbolRef{$hid} || $hid;
        my $name    = $$hugoID2NameRef{$hid} || '';
        my $occur   = $$hugoID2OccurRef{$hid} || 0;
        my $papers  = $$hugoID2PaperRef{$hid} || 0;
        my $pmids   = $$hugoID2PMIDsRef{$hid} || '';
        my $match   = $$hugoID2MatchRef{$hid} || '';

        # Clean up match string (remove trailing pipes and spaces)
        $match =~ s/\s*\|\s*$//;
        $match =~ s/^\s*\|\s*//;

        # Escape for JSON
        $name   = _json_escape($name);
        $match  = _json_escape($match);
        $symbol = _json_escape($symbol);
        $pmids  =~ s/,\s*$//;  # Remove trailing comma

        my $nodeJson = '{"data":{'
            . '"id":"' . $symbol . '",'
            . '"label":"' . $symbol . '",'
            . '"geneId":"' . $hid . '",'
            . '"name":"' . $name . '",'
            . '"papers":' . ($papers + 0) . ','
            . '"occur":' . ($occur + 0) . ','
            . '"pmids":"' . $pmids . '",'
            . '"matchString":"' . $match . '"'
            . '}}';

        push @nodeJsonParts, $nodeJson;
    }

    # Build edge JSON (limit total edges for performance in large networks)
    my $maxEdges = 2000;
    my @sortedEdgeKeys = sort { $edgePairs{$b}->{count} <=> $edgePairs{$a}->{count} } keys %edgePairs;

    my $edgeCount = 0;
    foreach my $key (@sortedEdgeKeys) {
        last if ($edgeCount >= $maxEdges);

        my ($ga, $gb) = split(/\t/, $key);
        my $symbolA = $$hugoID2SymbolRef{$ga} || $ga;
        my $symbolB = $$hugoID2SymbolRef{$gb} || $gb;
        my $count   = $edgePairs{$key}->{count};
        my $pmidStr = join(',', @{$edgePairs{$key}->{pmids}});

        $symbolA = _json_escape($symbolA);
        $symbolB = _json_escape($symbolB);

        my $edgeJson = '{"data":{'
            . '"source":"' . $symbolA . '",'
            . '"target":"' . $symbolB . '",'
            . '"sharedPapers":' . $count . ','
            . '"sharedPMIDs":"' . $pmidStr . '"'
            . '}}';

        push @edgeJsonParts, $edgeJson;
        $edgeCount++;
    }

    # Assemble final JSON
    my $json = '{"nodes":[' . join(',', @nodeJsonParts) . '],'
             . '"edges":[' . join(',', @edgeJsonParts) . '],'
             . '"metadata":{'
             . '"totalGenes":' . scalar(keys %uniqueIDs) . ','
             . '"totalEdges":' . $edgeCount . ','
             . '"totalEdgesUnfiltered":' . scalar(keys %edgePairs) . ','
             . '"generator":"SciMiner Network Generator"'
             . '}}';

    return $json;
}


# Escape a string for safe JSON embedding
sub _json_escape {
    my $str = shift;
    return '' unless defined $str;
    $str =~ s/\\/\\\\/g;
    $str =~ s/"/\\"/g;
    $str =~ s/\n/\\n/g;
    $str =~ s/\r/\\r/g;
    $str =~ s/\t/\\t/g;
    # Escape control characters
    $str =~ s/([\x00-\x1f])/sprintf("\\u%04x", ord($1))/ge;
    return $str;
}

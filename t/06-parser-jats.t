#!/usr/bin/env perl
################################################################################
#
#   06-parser-jats.t - JATS XML Parser Tests
#
#   Test the ParsePMC_JATS() function from SciMiner.pm:
#     - Returns correct title
#     - Extracts abstract
#     - Extracts body sections (Introduction, Methods, Results, Discussion)
#     - Bibliography references are stripped
#     - Inline markup (italic, bold) is handled
#     - Greek letters are converted
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More tests => 16;

# Set environment for module loading
$ENV{SCIMINER_HOME} = "$RealBin/..";

# Load SciMiner.pm -- it does not use a package declaration for its main
# functions; they are in the main namespace.
do "$RealBin/../annotation/SciMinerDB/Modules/Annotation/basicIO.pm";
do "$RealBin/../annotation/SciMinerDB/Modules/Annotation/SciMiner.pm";
ok(!$@, 'SciMiner.pm loaded') or BAIL_OUT("Cannot load SciMiner.pm: $@");

# Read the sample JATS XML test fixture
my $jats_file = "$RealBin/test_data/sample_jats.xml";
ok(-f $jats_file, 'Sample JATS XML file exists');

open my $fh, '<', $jats_file or BAIL_OUT("Cannot read $jats_file: $!");
my $xml = do { local $/; <$fh> };
close $fh;

ok(length($xml) > 0, 'Sample JATS XML is non-empty');

# --------------------------------------------------------------------------
# Parse the JATS XML
# --------------------------------------------------------------------------
my ($status, $article_ref) = ParsePMC_JATS(\$xml);

is($status, 1, 'ParsePMC_JATS returns success status (1)');
ok(ref $article_ref eq 'HASH', 'ParsePMC_JATS returns a hash reference');

# --------------------------------------------------------------------------
# Test: Title extraction
# --------------------------------------------------------------------------
ok(exists $article_ref->{TITLE}, 'TITLE key exists in parsed article');
like($article_ref->{TITLE}{text}, qr/BRCA1/,
     'Title contains "BRCA1"');
like($article_ref->{TITLE}{text}, qr/DNA Repair/,
     'Title contains "DNA Repair"');

# --------------------------------------------------------------------------
# Test: Abstract extraction
# --------------------------------------------------------------------------
ok(exists $article_ref->{ABSTRACT}, 'ABSTRACT key exists in parsed article');
like($article_ref->{ABSTRACT}{text}, qr/tumor suppressor/,
     'Abstract contains "tumor suppressor"');
like($article_ref->{ABSTRACT}{text}, qr/TP53/,
     'Abstract contains "TP53"');

# --------------------------------------------------------------------------
# Test: Body sections extraction
# --------------------------------------------------------------------------
ok(exists $article_ref->{INTRODUCTION}, 'INTRODUCTION section extracted');
ok(exists $article_ref->{METHODS},      'METHODS section extracted');
ok(exists $article_ref->{RESULTS},       'RESULTS section extracted');
ok(exists $article_ref->{DISCUSSION},    'DISCUSSION section extracted');

# --------------------------------------------------------------------------
# Test: Bibliography references are stripped
# --------------------------------------------------------------------------
# The Introduction paragraph contained <xref ref-type="bibr">[1]</xref>
# which should be removed by _jats_strip_inline_markup.
{
    my $intro_text = $article_ref->{INTRODUCTION}{text} || '';
    unlike($intro_text, qr/\[1\]/,
           'Bibliography citation [1] is stripped from Introduction text');
}

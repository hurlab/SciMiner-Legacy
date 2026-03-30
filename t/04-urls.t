#!/usr/bin/env perl
################################################################################
#
#   04-urls.t - External URL Validity Tests
#
#   Verify that critical external URLs used by SciMiner are reachable.
#   These tests are marked as TODO because they depend on network access.
#
################################################################################
use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/../annotation/SciMinerDB/Modules";

use Test::More;

# Check if LWP::UserAgent is available
eval { require LWP::UserAgent };
if ($@) {
    plan skip_all => 'LWP::UserAgent not installed -- skipping URL tests';
}

# External URLs to test -- these are the updated URLs from Config.pm
my @urls = (
    {
        name => 'PubMed',
        url  => 'https://pubmed.ncbi.nlm.nih.gov/',
    },
    {
        name => 'NCBI Gene',
        url  => 'https://www.ncbi.nlm.nih.gov/gene/',
    },
    {
        name => 'HGNC (genenames.org)',
        url  => 'https://www.genenames.org/',
    },
    {
        name => 'QuickGO (EBI)',
        url  => 'https://www.ebi.ac.uk/QuickGO/',
    },
    {
        name => 'NCBI E-utilities (esearch)',
        url  => 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi',
    },
    {
        name => 'KEGG Pathway',
        url  => 'https://www.genome.jp/pathway/hsa',
    },
    {
        name => 'Reactome',
        url  => 'https://reactome.org/',
    },
);

plan tests => scalar @urls;

my $ua = LWP::UserAgent->new(
    timeout    => 15,
    agent      => 'SciMiner-Test/1.0',
    ssl_opts   => { verify_hostname => 1 },
    max_redirect => 5,
);

TODO: {
    local $TODO = 'Network-dependent tests -- may fail without internet access';

    foreach my $entry (@urls) {
        my $response = $ua->head($entry->{url});
        my $code = $response->code;

        ok($code >= 200 && $code < 400,
           sprintf('%s (%s) responds with HTTP %d', $entry->{name}, $entry->{url}, $code))
            or diag("HTTP $code: " . $response->status_line);
    }
}

#!/usr/bin/perl
use strict;
use warnings;

print "Checking system Perl modules for SciMiner...\n\n";

my @modules = (
    'DBI',
    'DBD::mysql',
    'CGI',
    'CGI::Session',
    'CGI::Application',
    'HTML::Template',
    'YAML',
    'YAML::XS',
    'Text::NSP',
    'Spreadsheet::WriteExcel',
    'Data::Dumper',
    'Boulder::Medline',
    'DBD::SQLite',
    'XML::LibXML',
    'XML::Parser',
    'JSON',
);

my %status;

foreach my $module (@modules) {
    eval "use $module ();";
    if ($@) {
        $status{$module} = "Missing";
    } else {
        no strict 'refs';
        my $version = ${"${module}::VERSION"} || "Unknown";
        $status{$module} = "Installed ($version)";
    }
}

print "Module Status:\n";
print "-------------\n";
foreach my $module (sort keys %status) {
    printf "%-25s %s\n", $module, $status{$module};
}

print "\nSummary:\n";
my $missing = grep { $status{$_} eq "Missing" } keys %status;
print "Total modules checked: " . scalar(@modules) . "\n";
print "Missing modules: $missing\n";
print "Available modules: " . (scalar(@modules) - $missing) . "\n";
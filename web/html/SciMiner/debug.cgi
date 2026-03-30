#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

use strict;
use warnings;
use CGI qw(:standard);

print header(-type => 'text/html');
print start_html("Debug Information");

print h1("Perl CGI Debug Information");
print p("Perl is working!");

print h2("Perl Version");
print p($]);

print h2("Environment Variables");
print "<table border='1'>";
print "<tr><th>Variable</th><th>Value</th></tr>";
foreach my $key (sort keys %ENV) {
    print "<tr><td>$key</td><td>$ENV{$key}</td></tr>\n";
}
print "</table>";

print h2("Perl Module Check");
print "<table border='1'>";
print "<tr><th>Module</th><th>Status</th></tr>";

my @modules = ('DBI', 'DBD::mysql', 'CGI', 'CGI::Session', 'HTML::Template');
foreach my $module (@modules) {
    eval "use $module ()";
    if ($@) {
        print "<tr><td>$module</td><td>Missing: $@</td></tr>\n";
    } else {
        print "<tr><td>$module</td><td>Available</td></tr>\n";
    }
}
print "</table>";

print end_html;
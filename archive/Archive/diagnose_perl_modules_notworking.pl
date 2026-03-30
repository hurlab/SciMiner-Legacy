#!/usr/bin/perl
use strict;
use warnings;

print "SciMiner Perl Module Diagnostic Tool\n";
print "=====================================\n\n";

# Check for gcc and make
print "Build Tools Check:\n";
print "gcc: " . (`which gcc` ? "Found at " . `which gcc` : "NOT FOUND\n");
print "make: " . (`which make` ? "Found at " . `which make` : "NOT FOUND\n");

# Check for critical development headers
print "\nDevelopment Headers Check:\n";
my @headers = (
    '/usr/include/yaml.h' => 'libyaml-dev',
    '/usr/include/libxml2' => 'libxml2-dev',
    '/usr/include/mysql/mysql.h' => 'libmysqlclient-dev',
);

for my $header_check (@headers) {
    my ($path, $package) = @$header_check;
    if (-e $path) {
        print "✓ $package header found\n";
    } else {
        print "✗ $package header missing (expected at $path)\n";
    }
}

# Check Perl modules
print "\nPerl Module Status:\n";
my @modules = (
    ['YAML', 'Basic YAML support (alternative to YAML::XS)'],
    ['YAML::XS', 'Fast YAML with C bindings'],
    ['XML::LibXML', 'XML parsing with libxml2'],
    ['XML::Parser', 'XML parsing with expat'],
    ['CGI::Session', 'Session management'],
    ['CGI::Application', 'Web framework'],
    ['Text::NSP', 'N-gram statistics'],
    ['Spreadsheet::WriteExcel', 'Excel file writing'],
    ['JSON', 'JSON handling'],
    ['DBD::SQLite', 'SQLite database driver'],
    ['Boulder::Medline', 'Medline parsing (custom needed)'],
);

for my $module_info (@modules) {
    my ($module, $description) = @$module_info;
    eval "use $module ();";
    if ($@) {
        if ($@ =~ /Can't locate/) {
            printf "✗ %-25s - MISSING - %s\n", $module, $description;
        } else {
            printf "⚠ %-25s - ERROR - %s\n", $module, $@;
        }
    } else {
        no strict 'refs';
        my $version = ${"${module}::VERSION"} || "Unknown";
        printf "✓ %-25s - v%-6s - %s\n", $module, $version, $description;
    }
}

print "\nRecommendations:\n";
print "1. Install build tools: apt-get install build-essential gcc make\n";
print "2. Install dev headers: apt-get install libyaml-dev libxml2-dev\n";
print "3. Install packages: ./install_system_perl_packages.sh\n";
print "4. For YAML::XS issues: ./fix_yaml_xs.sh\n";
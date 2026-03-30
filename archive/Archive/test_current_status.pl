#!/home/sciminer/miniconda3/envs/sciminer/bin/perl

print "SciMiner Module Status Check\n";
print "===========================\n\n";

# List of required modules
my @modules = (
    'DBI',
    'DBD::MySQL',
    'DBD::SQLite',
    'CGI',
    'CGI::Session',
    'CGI::Application',
    'HTML::Template',
    'YAML',
    'YAML::XS',
    'Text::NSP',
    'XML::LibXML',
    'XML::Parser',
    'Spreadsheet::WriteExcel',
    'Data::Dumper',
    'Boulder::Medline'
);

print "Module Status:\n";
print "-------------\n";

my $ok_count = 0;
my $fail_count = 0;

foreach my $module (@modules) {
    eval "use $module";
    if ($@) {
        print "FAIL: $module\n";
        $fail_count++;
    } else {
        no strict 'refs';
        my $version = ${"${module}::VERSION"};
        $version = 'N/A' unless $version;
        print "OK:   $module (v$version)\n";
        $ok_count++;
    }
}

print "\nSummary:\n";
print "--------\n";
print "OK modules: $ok_count\n";
print "Failed modules: $fail_count\n";
print "\n";

# Test database connection if DBI and DBD::MySQL are available
if (eval { require DBI; require DBD::MySQL; }) {
    print "Testing database connection...\n";
    my $dsn = "DBI:mysql:database=sciminer;host=localhost";
    eval {
        my $dbh = DBI->connect($dsn, 'sciminer', '124356', {
            RaiseError => 0,
            PrintError => 0,
            AutoCommit => 1
        });

        if ($dbh) {
            print "Database connection: SUCCESS\n";

            # Check if tables exist
            my $sth = $dbh->prepare("SHOW TABLES");
            $sth->execute();
            my @tables;
            while (my @row = $sth->fetchrow_array()) {
                push @tables, $row[0];
            }
            print "Tables found: " . join(", ", @tables) . "\n" if @tables;

            $dbh->disconnect();
        } else {
            print "Database connection: FAILED - Could not connect\n";
        }
    };
    if ($@) {
        print "Database connection error: $@\n";
    }
}

print "\nDone.\n";
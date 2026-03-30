#!/usr/bin/perl
# Script to migrate existing plain text passwords to bcrypt hashes

use strict;
use warnings;
use DBI;
use FindBin;
use lib $FindBin::Bin;
BEGIN {
    my $base = $ENV{SCIMINER_HOME} || '/home/sciminer/legacy';
    unshift @INC, "$base/annotation/SciMinerDB/Modules";
    unshift @INC, "$base/annotation/SciMinerDB/Modules/SciMiner";
}
use SciMiner::Security qw(hash_password);

# Database configuration
my $dbname = "sciminer";
my $host = "localhost";
my $user = "sciminer";
my $password = "124356!@";

# Connect to database
my $dsn = "DBI:mysql:database=$dbname;host=$host";
my $dbh = DBI->connect($dsn, $user, $password, {
    RaiseError => 1,
    AutoCommit => 1
}) or die "Cannot connect to database: $DBI::errstr";

print "Starting password migration...\n";

# Get all users with plain text passwords
my $sth = $dbh->prepare("
    SELECT userID, email, password
    FROM user
    WHERE password_hash IS NULL
    AND password IS NOT NULL
");
$sth->execute();

my $migrated = 0;
my $total = 0;

while (my $row = $sth->fetchrow_hashref) {
    $total++;

    # Skip if password appears to already be hashed
    if ($row->{password} =~ /^\$2[aby]\$/) {
        print "Skipping user $row->{email} - password appears already hashed\n";
        next;
    }

    # Hash the password
    my $hashed = hash_password($row->{password});

    # Update the user record
    my $update = $dbh->prepare("
        UPDATE user
        SET password_hash = ?,
            email_verified = TRUE
        WHERE userID = ?
    ");

    if ($update->execute($hashed, $row->{userID})) {
        print "Migrated user: $row->{email} (ID: $row->{userID})\n";
        $migrated++;
    } else {
        print "ERROR: Failed to migrate user $row->{email}\n";
    }
}

print "\nMigration complete!\n";
print "Total users processed: $total\n";
print "Passwords migrated: $migrated\n";

# Note: Don't delete plain text passwords yet - allow for rollback
print "\nNOTE: Original passwords kept for backup. Remove 'password' column after confirming migration success.\n";

$sth->finish();
$dbh->disconnect();
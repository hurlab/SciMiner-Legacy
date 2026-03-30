package Annotation::SciMinerSecurity;
use strict;
use warnings;
use DBI;
use base 'Exporter';
our @EXPORT = qw(SciMiner_secure_email_password_check);
our @EXPORT_OK = qw(SciMiner_secure_email_password_check);

# Import security functions
use SciMiner::Security qw(verify_password);

# Secure email and password check with bcrypt
sub SciMiner_secure_email_password_check {
    my $email               = shift;
    my $passCodeEntered     = shift;

    #  Load working environment for ANNOTATION
    my %annoENV = anno_environmental_file_open ();
    my $annoBaseDir = $annoENV{ANNOPath};

    #  Database Access Information
    my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB with prepared statements
    #  ------------------------------------------------------------------------
    my $dbh = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) ||
              return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

    # Use prepared statement to prevent SQL injection
    my $sql = "SELECT password_hash, passCode, activationStatus, suspended, userID, last_login
              FROM user WHERE email = ? LIMIT 1";
    my $sth = $dbh->prepare($sql);
    $sth->execute($email);
    my @row = $sth->fetchrow_array;

    # Check if user exists
    if (!@row) {
        $sth->finish();
        $dbh->disconnect();
        return 0;  # User not found
    }

    my ($password_hash, $plain_password, $activationStatus, $suspended, $userID, $last_login) = @row;

    # Check if account is suspended
    if ((defined $suspended) && ($suspended == 1)) {
        $sth->finish();
        $dbh->disconnect();
        return 'SUSPENDED';
    }

    # Check if account is activated
    if ((defined $activationStatus) && ($activationStatus != 1)) {
        $sth->finish();
        $dbh->disconnect();
        return 'NOT_ACTIVATED';
    }

    # First try to verify against password_hash (bcrypt)
    if ($password_hash && verify_password($passCodeEntered, $password_hash)) {
        # Update last login time
        my $update = $dbh->prepare("UPDATE user SET last_login = NOW() WHERE userID = ?");
        $update->execute($userID);

        $sth->finish();
        $update->finish();
        $dbh->disconnect();
        return 1;  # Success
    }

    # Fallback to plain text password (for migration)
    elsif ($plain_password && $passCodeEntered eq $plain_password) {
        # TODO: Hash the plain text password and update database
        # This should be done during migration phase

        $sth->finish();
        $dbh->disconnect();
        return 1;  # Success - but needs migration
    }

    $sth->finish();
    $dbh->disconnect();
    return 0;  # Invalid password
}

# Get user info by email (secure version)
sub get_user_info_secure {
    my $email = shift;

    #  Load working environment for ANNOTATION
    my %annoENV = anno_environmental_file_open ();
    my $SciMinerDB = "DBI:mysql:database=".$annoENV{DB};
    my $username = $annoENV{username};
    my $password = $annoENV{password};

    my $dbh = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) ||
              return undef;

    my $sth = $dbh->prepare("SELECT userID, name, email, last_login FROM user WHERE email = ? LIMIT 1");
    $sth->execute($email);
    my $row = $sth->fetchrow_hashref;

    $sth->finish();
    $dbh->disconnect();

    return $row;
}

1;
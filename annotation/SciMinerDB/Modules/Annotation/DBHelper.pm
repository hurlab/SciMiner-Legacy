################################################################################
#
# Database Helper module for SciMiner
#
# Provides database connection handling with fallbacks
#
################################################################################

package Annotation::DBHelper;

use strict;
use warnings;
use DBI;
use Exporter 'import';
our @EXPORT = qw(db_connect db_execute db_query db_disconnect);

# Global database handle
my $dbh = undef;

# Subroutine: db_connect
# Connect to database with error handling
sub db_connect {
    my ($dsn, $user, $pass, $attr) = @_;

    # Default attributes
    $attr ||= {
        RaiseError => 0,
        PrintError => 0,
        AutoCommit => 1,
    };

    # Try to connect
    $dbh = DBI->connect($dsn, $user, $pass, $attr);

    unless ($dbh) {
        warn "Database connection failed: " . DBI->errstr;
        return undef;
    }

    return $dbh;
}

# Subroutine: db_execute
# Execute a prepared statement
sub db_execute {
    my ($sql, @bind) = @_;

    return undef unless $dbh;

    my $sth = $dbh->prepare($sql);
    unless ($sth) {
        warn "Prepare failed: " . $dbh->errstr;
        return undef;
    }

    my $rv = $sth->execute(@bind);
    unless ($rv) {
        warn "Execute failed: " . $sth->errstr;
        return undef;
    }

    return $sth;
}

# Subroutine: db_query
# Execute query and return results
sub db_query {
    my ($sql, @bind) = @_;

    my $sth = db_execute($sql, @bind);
    return undef unless $sth;

    my @results;
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    }

    $sth->finish;
    return \@results;
}

# Subroutine: db_disconnect
# Disconnect from database
sub db_disconnect {
    if ($dbh) {
        $dbh->disconnect;
        $dbh = undef;
    }
}

# Destructor - ensure disconnection
END {
    db_disconnect();
}

1;
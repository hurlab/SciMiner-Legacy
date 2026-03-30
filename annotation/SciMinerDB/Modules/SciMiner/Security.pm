package SciMiner::Security;
use strict;
use warnings;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
use MIME::Base64 qw(encode_base64);
use Exporter qw(import);
our @EXPORT_OK = qw(hash_password verify_password generate_token);

# Hash a password using bcrypt
sub hash_password {
    my ($password) = @_;
    die "Password required" unless defined $password;

    # Generate a random salt
    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[map { rand 64 } (1..22)];

    # Cost factor (higher = more secure but slower)
    my $cost = 12;

    # Create the bcrypt hash
    my $hash = bcrypt($password, '$2a$' . $cost . '$' . $salt);

    return $hash;
}

# Verify a password against its hash
sub verify_password {
    my ($password, $stored_hash) = @_;
    return 0 unless defined $password && defined $stored_hash;

    # Extract the salt from the stored hash
    return bcrypt($password, $stored_hash) eq $stored_hash;
}

# Generate a random token for sessions, CSRF, etc.
sub generate_token {
    my $length = shift || 32;
    my @chars = ('a'..'z', 'A'..'Z', 0..9);
    my $token = join '', map $chars[rand @chars], 1..$length;
    return $token;
}

1;
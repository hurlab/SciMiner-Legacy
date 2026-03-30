package SciMiner::Config;
use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(get_config load_env);

# Load environment variables from .env file
sub load_env {
    my $env_file = shift || ($ENV{SCIMINER_HOME} || '/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1') . '/.env.sciminer';

    if (-f $env_file) {
        open(my $fh, '<', $env_file) or die "Cannot open env file: $!";
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*#/;  # Skip comments
            next if $line =~ /^\s*$/;  # Skip empty lines

            if ($line =~ /^\s*([^=]+?)\s*=\s*(.*?)\s*$/) {
                my $key = $1;
                my $value = $2;

                # Remove quotes if present
                $value =~ s/^"(.*)"$/$1/;
                $value =~ s/^'(.*)'$/$1/;

                # Set environment variable
                $ENV{$key} = $value;
            }
        }
        close($fh);
    }
}

# Get configuration value with fallback
sub get_config {
    my ($key, $default) = @_;

    # Load environment if not loaded
    load_env() unless $ENV{'SCIMINER_CONFIG_LOADED'};
    $ENV{'SCIMINER_CONFIG_LOADED'} = 1;

    return $ENV{$key} || $default;
}

# Get database configuration
sub get_db_config {
    return {
        database => get_config('DB_NAME', 'sciminer'),
        host     => get_config('DB_HOST', 'localhost'),
        port     => get_config('DB_PORT', '3306'),
        username => get_config('DB_USER', 'sciminer'),
        password => get_config('DB_PASSWORD', '')
    };
}

# Get security configuration
sub get_security_config {
    return {
        session_timeout     => get_config('SESSION_TIMEOUT', 3600),
        bcrypt_cost         => get_config('BCRYPT_COST', 12),
        max_login_attempts  => get_config('MAX_LOGIN_ATTEMPTS', 5),
        account_lockout_time => get_config('ACCOUNT_LOCKOUT_TIME', 900),
        csrf_secret         => get_config('CSRF_SECRET_KEY', ''),
        session_key         => get_config('SESSION_ENCRYPTION_KEY', ''),
        jwt_secret          => get_config('JWT_SECRET_KEY', '')
    };
}

1;
package Annotation::basicIO_Secure;
use strict;
use warnings;
use Exporter qw(import);
our @EXPORT = qw(anno_environmental_file_open_secure);

# Import config module
use SciMiner::Config qw(get_config);

# Secure environment file opener that prioritizes environment variables
sub anno_environmental_file_open_secure {
    my $config_file = shift || "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/annotationENV.ini";
    my %env;

    # Load from environment variables first (more secure)
    $env{DB} = get_config('DB_NAME');
    $env{username} = get_config('DB_USER');
    $env{password} = get_config('DB_PASSWORD');
    $env{host} = get_config('DB_HOST', 'localhost');
    $env{port} = get_config('DB_PORT', '3306');

    # Set application paths
    $env{ANNOPath} = get_config('ANNOTATION_PATH', '/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/');
    $env{MaxDoc} = get_config('MAX_DOCUMENTS', 1000);
    $env{MaxNewDoc} = get_config('MAX_NEW_DOCUMENTS', 100);

    # Set SciMinerDB connection string
    $env{SciMinerDB} = "DBI:mysql:database=" . $env{DB} . ";host=" . $env{host} . ";port=" . $env{port};

    # Fallback to file if environment variables are not set
    if (!defined $env{DB} || !defined $env{username}) {
        if (open my $fh, '<', $config_file) {
            while (my $line = <$fh>) {
                chomp $line;
                next if $line =~ /^\s*#/;
                next if $line =~ /^\s*$/;
                if ($line =~ /^\s*([^=]+)\s*=\s*(.*?)\s*$/) {
                    my $key = $1;
                    my $value = $2;
                    $value =~ s/^\s*"(.*)"\s*$/$1/;
                    $env{$key} = $value unless defined $env{$key};
                }
            }
            close $fh;

            # Rebuild SciMinerDB connection string
            $env{SciMinerDB} = "DBI:mysql:database=" . $env{DB} .
                               ";host=" . ($env{host} || 'localhost') .
                               ";port=" . ($env{port} || '3306');
        }
    }

    return %env;
}

1;
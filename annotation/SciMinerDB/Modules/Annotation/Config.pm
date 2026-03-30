################################################################################
#
# Configuration module for SciMiner
#
# Handles all configuration including paths, URLs, and settings
#
################################################################################

package Annotation::Config;

use strict;
use warnings;
use Cwd 'abs_path';
use File::Spec;
use FindBin;

# Export configuration variables
use Exporter 'import';
our @EXPORT = qw(
    %config
    get_base_dir
    get_web_path
    get_anno_path
    get_module_path
);

# Global configuration hash
our %config = ();

# Initialize configuration (sub defined before BEGIN to avoid undefined subroutine error)
sub _init_config {
    # Get base directory automatically
    my $base_dir = $FindBin::Bin;
    $base_dir =~ s/\/(Modules|scripts|cgi-bin).*//;
    $base_dir = abs_path($base_dir);

    # Default paths
    my $default_base = $ENV{SCIMINER_HOME} || $base_dir || '/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1';

    # Set configuration values
    %config = (
        # Base directories
        BASE_DIR          => $default_base,
        ANNO_PATH         => "$default_base/annotation/",
        SCIMINER_PATH     => "$default_base/annotation/SciMinerDB/",
        SCIMINER_WEB_PATH => "$default_base/web/html/SciMiner/",
        WEB_PATH          => "$default_base/web/html/",

        # Module paths
        MODULE_PATH       => "$default_base/annotation/SciMinerDB/Modules/",
        ANNOTATION_PATH   => "$default_base/annotation/SciMinerDB/Modules/Annotation/",

        # Temporary paths
        TEMP_PATH         => $ENV{SCIMINER_TEMP} || '/tmp/SciMiner/',

        # URLs (read from ENV or use defaults)
        SERVER_URL        => $ENV{SCIMINER_SERVER_URL} || 'http://localhost:8888/',

        # Database configuration
        DB_NAME           => $ENV{SCIMINER_DB} || 'sciminer',
        DB_USER           => $ENV{SCIMINER_DB_USER} || 'sciminer',
        DB_PASS           => $ENV{SCIMINER_DB_PASS} || '124356',
        DB_HOST           => $ENV{SCIMINER_DB_HOST} || 'localhost',

        # External URLs
        URLS => {
            GO_BROWSER1    => "https://www.ebi.ac.uk/QuickGO/search/",
            GO_BROWSER2    => "",  # QuickGO uses unified search
            GO_BROWSER3    => "",  # QuickGO uses unified search
            GO_BROWSER4    => "https://www.ebi.ac.uk/QuickGO/term/",
            HGNC           => "https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/",
            NCBI_MESH      => "https://www.ncbi.nlm.nih.gov/mesh/?term=",
            NCBI_PUBMED    => "https://pubmed.ncbi.nlm.nih.gov/?term=",
            NCBI_GENE      => "https://www.ncbi.nlm.nih.gov/gene/",
            NCBI_GENE_SEARCH => "https://www.ncbi.nlm.nih.gov/gene/?term=",
            MIMI_NAME      => "http://mimi.ncibi.org/cytoscape/launcher?queryMiMIById=",  # DEPRECATED: MiMI service discontinued
            KEGG           => "https://www.genome.jp/pathway/hsa",
            REACTOME       => "https://reactome.org/content/detail/",
        },

        # UI Colors
        COLORS => {
            TG_CORPUS      => '#FA6161',  # Target corpus table background
            BG_CORPUS      => '#75FA95',  # Background corpus table background
            COMMON         => '#F3F798',  # Yellowish color
        },

        # Tags
        TAGS => {
            TG_ZERO        => 'tZero',    # Target corpus size is zero
            BG_ZERO        => 'bZero',    # Background corpus size is zero
        },

        # Admin settings
        ADMIN_EMAIL      => $ENV{SCIMINER_ADMIN_EMAIL} || 'sciminer@localhost',

        # Processing settings
        MAX_DOCS         => $ENV{SCIMINER_MAX_DOCS} || 1000,
        MAX_NEW_DOCS     => $ENV{SCIMINER_MAX_NEW_DOCS} || 500,

        # Debug settings
        DEBUG            => $ENV{SCIMINER_DEBUG} || 0,
        LOG_LEVEL        => $ENV{SCIMINER_LOG_LEVEL} || 'INFO',
    );

    # Override with annotationENV.ini if it exists
    _load_env_file();
}

sub _load_env_file {
    my @env_files = (
        "$config{SCIMINER_PATH}/annotationENV.ini",
        "$config{BASE_DIR}/annotation/SciMinerDB/annotationENV.ini",
        "/etc/sciminer/annotationENV.ini",
    );

    foreach my $env_file (@env_files) {
        next unless -f $env_file;

        open my $fh, '<', $env_file or next;
        while (my $line = <$fh>) {
            $line =~ s/\r|\n//g;
            next if $line =~ /^\s*#/ || $line =~ /^\s*$/;

            my @parts = split(/\s*=\s*/, $line, 2);
            if (@parts == 2) {
                my ($key, $value) = @parts;
                # Convert to uppercase for consistency
                $key = uc($key);
                $config{$key} = $value if $key;
            }
        }
        close $fh;
        last;  # Use first file found
    }
}

# Run initialization after all subs are defined
BEGIN { _init_config(); }

# Helper functions
sub get_base_dir {
    return $config{BASE_DIR};
}

sub get_web_path {
    return $config{SCIMINER_WEB_PATH};
}

sub get_anno_path {
    return $config{ANNO_PATH};
}

sub get_module_path {
    return $config{MODULE_PATH};
}

sub get_url {
    my ($key) = @_;
    return $config{URLS}{$key} || '';
}

sub get_color {
    my ($key) = @_;
    return $config{COLORS}{$key} || '';
}

sub get_tag {
    my ($key) = @_;
    return $config{TAGS}{$key} || '';
}

sub get {
    my ($key, $default) = @_;
    return exists $config{$key} ? $config{$key} : $default;
}

sub set {
    my ($key, $value) = @_;
    $config{$key} = $value;
}

# Dump configuration for debugging
sub dump_config {
    require Data::Dumper;
    print Data::Dumper::Dumper(\%config);
}

1;

__END__

=head1 NAME

Annotation::Config - Configuration module for SciMiner

=head1 SYNOPSIS

    use Annotation::Config;

    # Get base directory
    my $base_dir = get_base_dir();

    # Get web path
    my $web_path = get_web_path();

    # Get configuration value
    my $db_user = get('DB_USER', 'default_user');

    # Get URL
    my $ncbi_url = get_url('NCBI_PUBMED');

=head1 DESCRIPTION

This module centralizes all SciMiner configuration, eliminating hardcoded paths
throughout the codebase. It automatically detects the installation directory
and loads configuration from environment variables and annotationENV.ini.

=head1 CONFIGURATION

Configuration can be set via:

1. Environment variables (SCIMINER_*)
2. annotationENV.ini file
3. Default values in this module

=head1 AUTHOR

SciMiner Development Team

=cut
# Boulder::Medline - A lightweight Medline parser
# Compatibility module for SciMiner

package Boulder::Medline;

use strict;
use warnings;

# Class method to parse Medline format
sub parse {
    my ($class, $medline_text) = @_;

    # Return a blessed hash reference
    my $self = bless {
        _data => {},
        _raw_text => $medline_text
    }, $class;

    # Parse the Medline text
    $self->_parse_text($medline_text);

    return $self;
}

# Parse Medline record
sub _parse_text {
    my ($self, $text) = @_;

    my %record;
    my $current_field = '';
    my @current_lines;

    # Split into lines
    my @lines = split /\n/, $text;

    foreach my $line (@lines) {
        # Check for field tags (e.g., "PMID- ", "TI  - ")
        if ($line =~ /^([A-Z]{2,4})-?\s*(.+)$/) {
            # Save previous field if exists
            if ($current_field && @current_lines) {
                $record{$current_field} = join(' ', @current_lines);
            }

            $current_field = $1;
            $current_lines[0] = $2;
        }
        elsif ($line =~ /^\s+(.+)$/ && $current_field) {
            # Continuation line
            push @current_lines, $1;
        }
    }

    # Save last field
    if ($current_field && @current_lines) {
        $record{$current_field} = join(' ', @current_lines);
    }

    # Store parsed data
    $self->{_data} = \%record;
}

# Accessor methods
sub AUTOLOAD {
    my $self = shift;
    my $method = our $AUTOLOAD;

    # Remove package name
    $method =~ s/.*://;

    # Return data if field exists
    return $self->{_data}{$method} if exists $self->{_data}{$method};

    # Try common field name mappings
    my %field_map = (
        'PMID' => 'PMID',
        'TI' => 'TITLE',
        'AB' => 'ABSTRACT',
        'AU' => 'AUTHOR',
        'TA' => 'JOURNAL',
        'MH' => 'MESH',
    );

    my $mapped_field = $field_map{$method};
    return $self->{_data}{$mapped_field} if $mapped_field && exists $self->{_data}{$mapped_field};

    return '';
}

# Get specific field
sub get {
    my ($self, $field) = @_;
    return $self->{_data}{$field} || '';
}

# Get all fields
sub get_fields {
    my $self = shift;
    return keys %{$self->{_data}};
}

# Check if field exists
sub has_field {
    my ($self, $field) = @_;
    return exists $self->{_data}{$field};
}

# Get raw text
sub get_raw {
    my $self = shift;
    return $self->{_raw_text};
}

# Destructor
sub DESTROY {
    my $self = shift;
    # Cleanup if needed
}

1;

__END__

=head1 NAME

Boulder::Medline - Lightweight Medline record parser

=head1 SYNOPSIS

use Boulder::Medline;

my $medline_text = <<EOF;
PMID- 12345678
TI  - Article Title
AB  - Article abstract text...
AU  - Author One
AU  - Author Two
MH  - MeSH Term
MH  - Another MeSH Term
EOF

my $record = Boulder::Medline->parse($medline_text);
print $record->PMID;  # 12345678
print $record->TI;    # Article Title
print $record->AB;    # Article abstract text...

=head1 DESCRIPTION

Boulder::Medline is a lightweight parser for Medline format records.
It provides simple access to Medline fields through method calls
or the get() method.

=head1 METHODS

=over 4

=item parse($text)

Class method to parse Medline text and return a Boulder::Medline object.

=item get($field)

Get the value of a specific field.

=item get_fields()

Get a list of all field names in the record.

=item has_field($field)

Check if a specific field exists in the record.

=item get_raw()

Get the raw unparsed text.

=back

=head1 AUTHOR

SciMiner Development Team

=cut
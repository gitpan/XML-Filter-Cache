# $Id: Cache.pm,v 1.1.1.1 2002/01/28 14:42:37 matt Exp $

package XML::Filter::Cache;
use strict;

use vars qw($VERSION $AUTOLOAD @ISA);

$VERSION = '0.01';

use XML::SAX::Base;
@ISA = qw(XML::SAX::Base);

use Storable ();

sub new {
    my $class = shift;
    my $opts = (@_ == 1) ? { %{shift(@_)} } : {@_};

    $opts->{Class} ||= 'File';
    {
        no strict 'refs';
        eval "require XML::Filter::Cache::$opts->{Class};" 
            unless ${"XML::Filter::Cache::".$opts->{Class}."::VERSION"};
        if ($@) {
            die $@;
        }
    }
    if (!$opts->{Key}) {
        die "Need a Key parameter to construct a cache\n";
    }

    return "XML::Filter::Cache::$opts->{Class}"->new($opts);
}

sub playback {
    my $self = shift;
    $self->open("r");
    while (my $record = $self->_read) {
        my $thawed = Storable::thaw($record);
        $self->_playback($thawed);
    }
    $self->close;
}

sub _playback {
    my ($self, $thawed) = @_;
    my ($method, $structure) = @$thawed;
    my $supermethod = "SUPER::$method";
    $self->$supermethod($structure);
}

sub record {
    my ($self, $event, $structure) = @_;
    my $frozen = Storable::nfreeze([$event, $structure]);
    $self->_write($frozen);
}

sub _read {
    die "Abstract base method _read called";
}

sub _write {
    die "Abstract base method _write called";
}

my @sax_events = qw(
    start_element
    end_element
    characters
    processing_instruction
    ignorable_whitespace
    start_prefix_mapping
    end_prefix_mapping
    start_cdata
    end_cdata
    skipped_entity
    notation_decl
    unparsed_entity_decl
    element_decl
    attribute_decl
    internal_entity_decl
    external_entity_decl
    comment
    start_dtd
    end_dtd
    start_entity
    end_entity
    );

my $methods = '';
foreach my $method (@sax_events) {
    $methods .= <<EOT
sub $method {
    my (\$self, \$param) = \@_;
    \$self->record($method => \$param);
    return \$self->SUPER::$method(\$param);
}
EOT
}
eval $methods;
if ($@) {
    die $@;
}

# Only some parsers call set_document_locator, and it's called before
# start_document. So we keep it in $self, and open the cache in start_document,
# then write out the set_document_locator event
sub set_document_locator {
    my $self = shift;
    $self->SUPER::set_document_locator($self->{_locator} = shift);
}

sub start_document {
    my ($self, $doc) = @_;
    $self->open("w");
    if (my $locator = delete $self->{_locator}) {
        $self->record(set_document_locator => $locator);
    }
    $self->record(start_document => $doc);
    $self->SUPER::start_document($doc);
}

sub end_document {
    my ($self, $doc) = @_;
    $self->record(end_document => $doc);
    $self->close();
    $self->SUPER::end_document($doc);
}

1;
__END__

=head1 NAME

XML::Filter::Cache - a SAX2 recorder/playback mechanism

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE

=head1 AUTHOR

=cut

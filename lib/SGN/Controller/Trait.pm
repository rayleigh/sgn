package SGN::Controller::Trait;

=head1 NAME

SGN::Controller::Trait - Catalyst controller for pages dealing with traits (these are cvterms, specifically Solanaceae Phenotype terms)

=cut

use Moose;
use namespace::autoclean;

use HTML::FormFu;
use URI::FromHash 'uri';
use YAML::Any;
#use SGN::View::Trait qw/cvterm_link/;

has 'schema' => (
is => 'rw',
isa => 'DBIx::Class::Schema',
required => 0,
);

has 'default_page_size' => (
is => 'ro',
default => 20,
);


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';



sub _validate_pair {
    my ($self,$c,$key,$value) = @_;
    $c->throw( message => "$value is not a valid value for $key" )
        if ($key =~ m/_id$/ and $value !~ m/\d+/);
}

sub search :Path('/trait/search') Args(0) {
    my ( $self, $c ) = @_;
    $self->schema( $c->dbic_schema('Bio::Chado::Schema','sgn_chado') );

    #my $req = $c->req;
    my $browse = $self->_browse_traits($c);
    $c->stash(
        template => '/ontology/traits.mas',
        browse_link => $browse
        );
}

sub _browse_traits {
    my ($self, $c) = @_ ;
    my @indices = ('A'..'Z');
    my $link;
    foreach my $index (@indices) {
       
    }
    return $link;
}
sub _get_qtl_populations {
# this function should return a list of population type stocks with linked qtls!
}


######
1;
######
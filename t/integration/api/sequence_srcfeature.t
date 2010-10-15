=head1 NAME

t/integration/api/sequence_srcfeature.t - integration tests for API sequence URLs that use srcfeatures

=head1 DESCRIPTION

Tests for sequence API URLs

=head1 SYNOPSIS

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my $residue = 'AATTCCGG';
my $srcfeature    = create_test('Sequence::Feature', {
        residues => $residue,
});
my $feature    = create_test('Sequence::Feature', {
        residues => '',
});
my $featureloc = create_test('Sequence::Featureloc', {
    feature    => $feature,
    srcfeature => $srcfeature,
});

{
    # 3 = > + 2 newlines
    my $length = length($feature->name . $residue) + 3;
    $mech->get_ok('/api/v1/sequence/' . $feature->name . '.fasta');
    $mech->content_contains( '>' . $feature->name );
    $mech->content_contains( $residue );
    is('text/plain', $mech->content_type, 'text/plain content type');
    is( $length, length($mech->content), 'got the expected content length');
}
done_testing;

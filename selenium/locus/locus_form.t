=head1 NAME

t/integration/locus_form.t - tests for the ajax functions of the locus form

=head1 DESCRIPTION

Tests for locus ajax form

=head1 AUTHORS

Naama Menda

=cut
use Modern::Perl;

use Test::More;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;
use SGN::Test::WWW::Selenium;
use CXGN::DB::Connection;
use CXGN::People::Person;

# XXX: Temporary code until Selenium and SGN::Test::WWW::Mechanize are friends
sub create_test_user {
    my ($dbh, $user_type) = @_;
    if( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
        CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
    }
#
    my $p = CXGN::People::Person->new($dbh);
    $p->set_first_name("testfirstname");
    $p->set_last_name("testlastname");
    my $p_id = $p->store();

    my $login = CXGN::People::Login->new( $dbh, $p_id );
    $login->set_username("testusername");
    $login->set_password("testpassword");
    $login->set_user_type($user_type);

    $login->store();

    $dbh->commit();
}

sub login {
    my ($s) = @_;

    my %form = (
        form_name => 'login',
        fields    => {
            username => 'testusername',
            pd       => 'testpassword',
        },
    );

    diag("Submitting login form");
    $s->submit_form( \%form );

}

my $dbh = CXGN::DB::Connection->new();

my $server = $ENV{SGN_TEST_SERVER} || die 'no SGN_TEST_SERVER set';

my $s = SGN::Test::WWW::Selenium->new(
    browser_url => "$server/solpeople/top-level.pl",
);
create_test_user($dbh,'curator');
login($s);
#the page with the form
$s->open_ok("$server/phenome/locus_display?action=new");

#this is the ajax form
# $s->open_ok($server."/jsforms/locus_ajax_form.pl?action=new");

sleep(4); # wait for the page to load completely (AJAX actions)
my $source    = $s->get_html_source();
my $body_text = $s->get_body_text();

like($body_text, qr/Locus name/, "String match on page");
like($source, qr/edit_form/, "edit_form string present in source");
like($body_text, qr/store/, "Store button match");
like($body_text, qr/Organism/, "Organism field match");

done_testing;

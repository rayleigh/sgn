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
use Test::WWW::Selenium;

my $server = $ENV{SELENIUM_TEST_SERVER} || die "Need the ENV SELENIUM_TEST_SERVER set";
my $host   = $ENV{SELENIUM_HOST} || die "Need the ENV SELENIUM_HOST set";
my $browser = $ENV{SELENIUM_BROWSER} || die "Need the ENV SELENIUM_BROWSER set";


my $mech = SGN::Test::WWW::Mechanize->new;

$mech->while_logged_in( { user_type => 'curator' }, sub {
        my $user_info = shift;

   my $s = Test::WWW::Selenium->new(
     host        => $host,
     port        => 4444,
     browser     => $browser,
     browser_url => $server."/phenome/locus_display?action=new",
   );
   #this is the ajax form
   # $s->open_ok($server."/jsforms/locus_ajax_form.pl?action=new");

   #the page with the form
   $s->open_ok($server."/phenome/locus_display.pl?action=new");

   sleep(4); # wait for the page to load completely (AJAX actions)
   my $source    = $s->get_html_source();
   my $body_text = $s->get_body_text();

  like($body_text, qr/Locus name/, "String match on page");
  like($source, qr/edit_form/, "edit_form string present in source");
  like($body_text, qr/store/, "Store button match");
  like($body_text, qr/Organism/, "Organism field match");



});


done_testing;

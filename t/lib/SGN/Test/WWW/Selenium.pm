package SGN::Test::WWW::Selenium;

use Modern::Perl;
use Test::WWW::Selenium;

sub new {
    my ($c, %opts);
    return Test::WWW::Selenium->new(
        host        => ( $ENV{SELENIUM_HOST}      || 'winsel.sgn.cornell.edu' ),
        port        => ( $ENV{SELENIUM_HOST_PORT} || 4444 ),
        browser     => ( $ENV{SELENIUM_BROWSER}   || '*iexplore' ),
        browser_url => ( $ENV{SGN_TEST_SERVER} || 'http://localhost' ),
        %opts,
    );
}


1;

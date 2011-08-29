use strict;
use warnings;
use Test::More qw | no_plan |;
use lib 't/lib/';
#diag('Sees if it can use the modules');
BEGIN {
   use_ok('SGN::Feature::ExpressionViewer::Loader');
   use_ok('File::Temp', qw/ :seekable /);
   use_ok('CXGN::GEM::Schema');
}
my $schema_list = 'gem,biosource,metadata,public';

my $schema = CXGN::GEM::Schema->connect(sub{ $dbh },
                   { on_connect_do => ["SET search_path TO $schema_list"] });



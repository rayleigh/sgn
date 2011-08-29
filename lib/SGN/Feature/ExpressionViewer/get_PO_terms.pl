#!usr/bin/perl

use strict;
use warnings;
use CXGN::GEM::Schema;
use CXGN::GEM::Experiment;

my $schema_list = 'gem,biosource,metadata,public';

my $schema = CXGN::GEM::Schema->connect(sub{ $dbh },
                   { on_connect_do => ["SET search_path TO $schema_list"] });

open DATAFILE, "<", 'A10063_at_median_expr_level_and_exp_id.txt';
my %experiment_to_data = ();
while (<DATAFILE>)
{
    chomp;
    my @entries = split(/\t/);
    $experiment_to_data{$entries[0]} = $entries[1];
}
close DATAFILE;

open OUTFILE, ">", 'PO_terms_to_data for A10063.txt';
my @experiments = keys %experiment_to_data;
foreach my $exp_id (@experiments) 
{
   my $exp = CXGN::GEM::Experiment->new($schema, $exp_id);
   my %exp_po = ();
   my @targets = $exp->get_target_list();

   foreach my $target (@targets) {

       my $target_name = $target->get_target_name();
       my @samples = $target->get_sample_list();

       foreach my $sample (@samples) {

	   my $sample_name = $sample->get_sample_name();
	   my %dbxref_po = $sample->get_dbxref_related('PO');

	   foreach my $dbxref_id (keys %dbxref_po) {
	       unless (exists $exp_po{$dbxref_id}) {
		   $exp_po{$dbxref_id} = $dbxref_po{$dbxref_id};
		   print OUTFILE $dbxref_id . "\t" . 
				   $experiment_to_data{$exp_id}; 
	       }
	   }
       }
   }
}
close OUTFILE;

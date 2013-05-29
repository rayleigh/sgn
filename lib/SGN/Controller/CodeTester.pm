package SGN::Controller::Test;

use namespace::autoclean;
use Moose;
use SGN::ExpressionViewer::Loader;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'}

sub display :Path('/test/display')
{
   my ($self, $c) = @_;
   #my $message = $self->{other_info_file};
   my $loader = SGN::ExpressionViewer::Loader->new(
        'bcschema' => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
        'cgschema' => $c->dbic_schema('CXGN::GEM::Schema', 'sgn_chado'),
        'config_file_name' => $self->{conf_file},
        'other_info_file_name' => $self->{other_info_file});
   #$loader->store_PO_term_childs_and_order_in_conf_file;
   #$message .= "\n" . $loader->other_info_file_name . "\n";
   my @list_of_refs = $loader->get_refs_of_required_info('Stem and flower', 'A10063_at');
   my $message = ''; 
   #$message = Dumper($list_of_refs[2]) . "\n\n";
   #$message .= Dumper($list_of_refs[3]);
   #$message .= "\n" . scalar @list_of_refs;
   #$message .= Dumper($list_of_refs[0]);
   #for my $PO_term (@{$list_of_refs[5]})
   #{
      #$message .= $PO_term;
   #}
   $message .= Dumper($list_of_refs[4]);
   #$message .= \@list_of_refs;
   #$loader->store_PO_term_childs_and_order_in_conf_file;
   #my @list_of_picture_PO_terms =
        #$loader->get_list_of_all_PO_terms_in_picture('Stem and flower');
   #my $root_cv;
   #my %is_picture_term = map{$_ => 1} @list_of_picture_PO_terms;
   #for my $term (@list_of_picture_PO_terms)
   #{
      #my $term_accession = $1 if $term =~ /PO(\d*)/;
      #my $dbxref_id = $loader->bcschema->resultset(
	#'General::Db')->search_rs(
           #{name => 'PO'})->search_related(
	      #'dbxrefs', {accession => $term_accession})->get_column(
						#'dbxref_id')->first;
      #my $temp_cv = $loader->bcschema->resultset('Cv::Cvterm')
                      #->search_rs({dbxref_id => $dbxref_id})->first;
      #if ($temp_cv)
      #{
         #$root_cv = $temp_cv->root;
         #last;
      #}
   #}
   #my @child_cv_list = $root_cv->direct_children;
   #my $t1 = time;
   #my %has_been_called = ();
   #my $child_terms_ref = [];
   #for my $cv (@child_cv_list)
   #{
         #print "wait\n";
         #if ($cv eq 'done')
         #{
            #print "bam\n";
            #print @$child_terms_ref;
	    #%has_been_called = ();
            #$child_terms_ref = [];
         #}
         #else 
         #{
            #my $dbxref = $cv->dbxref_id;
            #unless ($has_been_called{$dbxref})
            #{
               #@child_cv_list = (@child_cv_list, 'done', $cv->direct_children);
               #$has_been_called{$dbxref} = 1;
            #}
	    #my $rs = $cv->recursive_children;
	    #while (my $result = $rs->next)
	    #{
	       #my $PO_term =  "PO" . $result->dbxref->accession;
	       #print $PO_term . "\n" 
		      #if $is_picture_term{$PO_term};
	       #push @$child_terms_ref, $PO_term if $is_picture_term{$PO_term};
	       #$message .= $result->dbxref->accession . "\n";
	    #}
	 #}
   #}
   #my $t2 = time;
   #print "$t1, $t2," . ($t1 - $t2) . "\n";
   #print "onwards";
   #$message .= "Bye" .$root_cv->dbxref_id . $root_cv->name . $root_cv->cv->name;
   #my $dbxref_id = $loader->bcschema->resultset('General::Db')->search_rs({name => 'PO'})->search_related('dbxrefs', {accession => '0006109'})->get_column('dbxref_id')->first;
   #my $cv = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado')->resultset('Cv::Cvterm')->search_rs({dbxref_id => $dbxref_id})->first;
   #$message .= "Hi" . $cv->root->dbxref_id . $cv->root->name . $cv->root->cv->name . "\n";
    #$message .= "Welcome" . join ",", map{ $_->dbxref_id  } $root_cv->recursive_children;
   $c->stash->{message} = $message;
   $c->stash->{template} = "/test.mas";
   #my ($data_ref, $exp_PO_guide_ref) =
                #$loader->get_data_and_exp_PO_guide('A10063_at');
   #$c->stash->{message} = $data_ref . $exp_PO_guide_ref;

}

sub submit :Path('/test/submit')
{
   my ($self, $c) = @_;
   $c->stash->{message} = $c->request->param('message_box') . $c ->request->param('checked');
   $c->stash->{template} = "/test.mas";
}

__PACKAGE__->meta->make_immutable;
1;

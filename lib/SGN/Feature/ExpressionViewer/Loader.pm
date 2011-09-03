package SGN::Feature::ExpressionViewer::Loader;
use Moose;
use Config::General;
use Bio::Chado::Schema;
use CXGN::GEM::Schema;
use CXGN::GEM::Expression;
use CXGN::GEM::Template;
use CXGN::GEM::Experiment;

has 'bcschema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1);
has 'cgschema' => (isa => 'CXGN::GEM::Schema', is => 'rw', required => 1);
has 'config_file_name' => (isa => 'Str', is => 'ro', required => 1);
has 'img_name_to_src' => (isa => 'HashRef[Str]', is => 'rw',); 
has 'img_info' => (isa => 'HashRef', is => 'rw',
			traits => ['Hash'], handles => {img_list => 'keys'}, 
		          		builder => '_parse_config_file');

#Parse a config file using Config::General
#For the format, please see /conf/eFP_config.conf
sub _parse_config_file
{
   my $self = shift;
   my $conf = new Config::General(-ConfigFile => $self->config_file_name,
				  -ForceArray => '1');
   my %config = $conf->getall;
   my (%tmp_img_name_to_src, %tmp_img_info, %PO_term_to_color, 
		%PO_term_location, %coord_to_link, @order_of_coord);
   for my $img_name (keys %config)
   {
      my $unsorted_img_info = $config{$img_name};
      $tmp_img_name_to_src{$img_name} = delete $$unsorted_img_info{'img_src'};
      for my $PO_term (keys %$unsorted_img_info) 
      {
         my $unsorted_PO_term_info = $$unsorted_img_info{$PO_term};

         #Removes the colon
	 $PO_term =~ s/://;

	 $PO_term_to_color{$PO_term} = 
				      $$unsorted_PO_term_info{'color'};
	 $PO_term_location{$PO_term} = 
				      $$unsorted_PO_term_info{'pixel'};
	 my $area_coord = $$unsorted_PO_term_info{'coord'};
         for my $coord (@$area_coord)
         {
	    $coord_to_link{$coord} = $$unsorted_PO_term_info{'link'};
            push @order_of_coord, $coord;
         }
      }
      $tmp_img_info{$img_name} = [\%PO_term_to_color,
                                         \%PO_term_location, 
					      \%coord_to_link,
						  \@order_of_coord];
   }
   $self->img_name_to_src(\%tmp_img_name_to_src);
   \%tmp_img_info;
}

#Returns a list of all PO terms in the picture
sub get_list_of_all_PO_terms_in_picture
{
   my ($self, $img_name) = @_;
   my $picture_PO_terms_ref = ${$self->img_info->{$img_name}}[0];
   return keys %$picture_PO_terms_ref;
}

#Links experiments to their expression data and and PO terms
#Also links PO terms to their children terms, finds the order of the terms, 
#and returns them
#Plus, returns a color and location guide of PO terms in the picture
#and a link between the PO terms' area and a url with more information
#Returns all as a reference
sub get_refs_of_required_info
{
   my ($self, $img_name, $template_name) = @_;
   my ($data_ref, $exp_PO_guide_ref) = 
			$self->get_data_and_exp_PO_guide($template_name);
   my ($PO_terms_child_ref, $PO_term_order_ref) = 
	$self->_get_PO_terms_childs_and_order($img_name); 
   return $data_ref, $exp_PO_guide_ref, $PO_term_order_ref,
	     			    ${$self->img_info->{$img_name}}[0],
		                       ${$self->img_info->{$img_name}}[1],
	                                  ${$self->img_info->{$img_name}}[2];
}

#Assigns data by experiment and returns a reference linking experiments to
#PO terms affected
sub get_data_and_exp_PO_guide
{
   my ($self, $template_name) = @_;
   my $cxgn_exp_obj = CXGN::GEM::Experiment->new($self->cgschema);
   my $temp_template =
        CXGN::GEM::Template->new_by_name($self->cgschema, $template_name);
   my $temp_expr =
        CXGN::GEM::Expression->new($self->cgschema,
                                        $temp_template->get_template_id);
   my %experiments = $temp_expr->get_experiment;
   my (%data, %exp_to_PO_terms);
   for my $exp_id (keys %experiments)
   {
      $cxgn_exp_obj->force_set_experiment_id($exp_id); 
      $data{$exp_id} = 
	      ${$experiments{$exp_id}}{'median'};
      my @targets = $cxgn_exp_obj->get_target_list();
      my %PO_term_included = ();
      foreach my $target (@targets) 
      {
         my @samples = $target->get_sample_list();
         foreach my $sample (@samples) 
         {
	     my %dbxref_po = $sample->get_dbxref_related('PO');
	     foreach my $dbxref_id (keys %dbxref_po) 
	     {
                 $PO_term_included{$dbxref_po{$dbxref_id}} = 1;
	     }
         } 
     }
     my @PO_terms = keys %PO_term_included;
     $exp_to_PO_terms{$exp_id} = \@PO_terms;
   }
   return \%data;
}

#Uses Bio::Chado::Schema to find the order of terms and their children
sub _get_PO_terms_childs_and_order
{
   my ($self, $img_name) = @_;
   my $PO_terms_childs_ref = {};
   my $PO_term_order_ref = [];
   my @list_of_picture_PO_terms = 
        $self->get_list_of_all_PO_terms_in_picture($img_name);
   my $first_PO_term = $list_of_picture_PO_terms[0];
   my $first_accession = $1 if $first_PO_term =~ /PO(\d*)/;
   my $dbxref_id = 
	 $self->bcschema->resultset('General::Dbxref')->search_rs(
	{accession => $first_accession})->get_column('dbxref_id')->first;
   my $root_cv = $self->bcschema->resultset('Cv::Cvterm')
		      ->search_rs({dbxref_id => $dbxref_id})->first->root;
   ($PO_terms_childs_ref, $PO_term_order_ref) = 
       $self->_update_PO_terms_childs($PO_terms_childs_ref, 
			                  $PO_term_order_ref, $root_cv,
					      \@list_of_picture_PO_terms);
   my @PO_terms = ($root_cv->direct_children);
   for my $rs (@PO_terms)
   {
      last if (scalar keys %$PO_terms_childs_ref ==
			      scalar $self->data_PO_terms); 
      while (my $PO_cv_term = $rs->next)
      {
	 last if (scalar keys %$PO_terms_childs_ref ==
	   			       scalar @list_of_picture_PO_terms); 
         @PO_terms = (@PO_terms, $PO_cv_term->direct_children);
         $PO_terms_childs_ref = 
	    $self->_update_PO_terms_childs($PO_terms_childs_ref,
 				 	      $PO_term_order_ref,
					         $PO_cv_term, 
						   \@list_of_picture_PO_terms);
      }
   }
   $PO_terms_childs_ref;
}

#Updates PO_terms_child
sub _update_PO_terms_childs
{
   my ($self, $PO_terms_childs_ref, $order_ref, 
		   $cv_term, $PO_term_in_picture_ref) = @_;
   my $accession = 'PO' . $cv_term->dbxref->accession;
   if ($$PO_term_in_picture_ref{$accession})
   {
      push @{$order_ref}, $accession;
      my @child_accession_list = 
          $self->_get_children_accession_from_rs(
		    $cv_term->recursive_children, $PO_term_in_picture_ref);
      $$PO_terms_childs_ref{$accession} = \@child_accession_list;
   }
   return $PO_terms_childs_ref, $order_ref;
}

#Combs through the rs set for children by checking if a term is in the picture
sub _get_children_accession_from_rs
{
   my ($self, $rs, $PO_terms_in_picture_ref) = @_;
   my @child_accession = ();
   while (my $child = $rs->next)
   {
      my $child_term = 'PO' . $child->dbxref->accession;
      push @child_accession, $child_term 
         		         if $$PO_terms_in_picture_ref{$child_term};
   }
   return @child_accession;
}

__PACKAGE__->meta->make_immutable;
1;

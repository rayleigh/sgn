package SGN::Feature::ExpressionViewer::Loader;
use Moose;
use Config::General;
use Bio::Chado::Schema::Cv;
use Bio::Chado::Schema;
use CXGN::GEM::Schema;
use CXGN::GEM::Expression;
use CXGN::GEM::Template;
use CXGN::GEM::Experiment;

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1);
has 'config_file_name' => (isa => 'Str', is => 'ro', required => 1);
has 'template_list' => (isa => 'ArrayRef[Str]', is => 'rw', 
			   traits => ['Array'],
 				handlers => {note_template => 'push'});
has 'img_name_to_src' => (isa => 'HashRef[Str]', is => 'rw',
			     traits => ['Hash'], 
				handlers => {img_list => 'keys'}); 
has 'img_info' => (isa => 'HashRef', is => 'rw', 
		      traits => ['Hash'], handlers => {info_list => 'values'},
		          builder => '_parse_config_file');

#Config file should have this format:
#PO term\tColor RGB value and include data\tCoordinate on map\tLink
#Ex: PO00001\t0,0,26,1\t22,33\thttp://www.plant.com/
#Includes data from data_source
#Ex: PO00003\t0,0,24,0\t22,50\thttp://www.plant.com/
#Does not include data from data_source
sub _parse_config_file
{
   my $self = shift;
   my $conf = new Config::General($self->config_file_name);
   my %config = $conf->getall;
   $self->template_list($config{'template'});
   $self->img_name_to_src(map {$_ => $config->{$_}} if $_ ne 'template'}
							       keys %config);
   my (@PO_term_order, %PO_term_to_color,
                                %PO_term_location, %coord_to_link);
   for my $img ($self->img_list)
   {
      my $unsorted_img_info = $config{$img};
      for my $PO_term (keys %$unsorted_img_info) 
      {
	 my $unsorted_PO_term_info = $$unsorted_img_info{$PO_term};
	 $PO_term_to_color{$PO_term} = 
				      $$unsorted_PO_term_info{'color'};
	 $PO_term_location{$PO_term} = 
				      $$unsorted_PO_term_info{'pixel'};
	 my $area_coord = $$unsorted_PO_term_info{'coord'};
	 $coord_to_link->{join('#', @$area_coord)} =
				      $$unsorted_PO_term_info{'link'};
      }
      $self->img_info->{$img} = [\%PO_term_to_color,
                                         \%PO_term_location, \%coord_to_link];
   }
   $self->img_info;
}

sub get_list_of_all_PO_terms_in_picture
{
   my ($self, $img_name) = @_;
   my $picture_PO_terms_ref = ${$self->img_info->{$img_name}}[0];
   return keys %$picture_PO_terms_ref;
}

#Links PO terms to their expression data and their children terms, finds 
#the order of the terms, and returns them
#Also returns a color and location guide of PO terms in the picture
#and a link between the PO terms' area and a link for more information
sub get_refs_of_required_info
{
   my ($self, $img_name, $exp_name, $template_name) = @_;
   my %data = $self->assign_data_to_terms($exp_name, $template_name, 
				        keys $full_picture_PO_terms_ref);
   my ($PO_terms_child_ref, $PO_term_order_ref) = 
	$self->_get_PO_terms_child_and_order(\%PO_term_to_full_term,
						 \%full_term_to_PO_term); 
   return \%data, \%PO_terms_child, $PO_term_order_ref,
	     			    $full_picture_PO_terms_ref,
		                       ${$self->img_info->{$img_name}}[1],
	                                  ${$self->img_info->{$img_name}}[2];
}

sub assign_data_to_terms
{
   my ($self, $exp_name, $template_name) = @_;
   my $cxgn_exp_obj = CXGN::GEM::Experiment->new_by_name($self->schema, 
							       $exp_name);
   my $temp_template =
        CXGN::GEM::Template->new_by_name($self->$schema, $template_name);
   my $temp_expr =
        CXGN::GEM::Expression->$temp_template->new($self->schema,
                                        $temp_template->get_template_id);
   my %experiments = $temp_expr->get_experiment;
   my $exp_id = $cxgn_exp_obj->get_experiment_id;
   my @targets = $exp->get_target_list();
   my %data;
   foreach my $target (@targets) 
   {
       my $target_name = $target->get_target_name();
       my @samples = $target->get_sample_list();
       foreach my $sample (@samples) 
       {
	   my $sample_name = $sample->get_sample_name();
	   my %dbxref_po = $sample->get_dbxref_related('PO');
	   foreach my $dbxref_id (keys %dbxref_po) 
	   {
	       $data{$dbxref_po{$dbxref_id}} = 
			 ${$experiments{$exp_id}}{'median'}};
	   }
       }
   }
   return \%data;
}

#Matches PO terms with their children
sub _match_PO_terms_with_children
{
   my ($PO_terms_child_ref, $PO_term_exists_in_pictures_ref) = @_;
   my %full_PO_terms_child; 
   for my $term (keys %$full_term_to_PO_term_ref)
   {
      my $child_ref = [];
      my ($exp_num, $PO_term) = $1 if $term =~ /(\d*)(PO\d*)/;
      for my $child (@{$PO_terms_child_ref{$PO_term}})
      {
         my $child_full_name = $exp_num . $child;
         push @{$child_ref}, $child_full_name 
		if $$PO_term_exists_in_pictures_ref{$PO_term};
      }
      $full_PO_terms_child{$term} = $child_ref;
   }
   return \%full_term_to_PO_term;
}

#Uses Bio::Chado::Schema to find the order of terms and their children
sub _get_PO_terms_childs_and_order
{
   my $self = shift;
   my $PO_terms_childs_ref = {};
   my $PO_term_order_ref = [];
   my $root_cv = 
	 $self->schema->resultset('General::Dbxref')->find(
		 {accession => (pop $self->data_PO_terms)})->cv_term->root;
   my ($PO_terms_childs_ref, $PO_term_order_ref) = 
       $self->_update_PO_terms_childs($PO_terms_childs_ref, $PO_cv_term, 
					               $PO_term_order_ref);
   my @PO_terms = ($root_cv->direct_children);
   for my $rs (@PO_terms)
   {
      last if (scalar keys %$PO_terms_childs_ref ==
			      scalar $self->data_PO_terms); 
      while (my $PO_cv_term = $rs->next)
      {
	 last if (scalar keys %$PO_terms_childs_ref ==
				 scalar keys %$PO_term_to_full_term); 
         @PO_terms = (@PO_terms, $PO_cv_term->direct_children);
         $PO_terms_childs_ref = 
	    $self->_update_PO_terms_childs($PO_terms_childs_ref,
 				 	      $PO_cv_term, $PO_term_order_ref);
      }
   }
   $PO_terms_childs_ref;
}

#Updates PO_terms_child
sub _update_PO_terms_childs
{
   my ($self, $PO_terms_childs_ref, $cv_term, $order_ref) = @_;
   my %PO_term_in_picture = map {$_ => 1} 
			      $self->get_list_of_all_PO_terms_in_picture;
   my $accession = $cv_term->dbxref->accession;
   if ($PO_term_in_picture{$accession})
   {
      push @{$order_ref}, $accession;
      my @child_accession_list = 
          $self->_get_children_accession_from_rs(
		    $cv_term->recursive_children, \%PO_term_in_picture);
      $$PO_terms_childs_ref{$accession} = \@child_accession_list;
   }
   return $PO_terms_childs_ref, $order_ref;
}

#Combs through the rs set for children by checking if a term is in the picture
sub _get_children_accession_from_rs
{
   my ($self, $rs, $PO_term_to_full_term_ref) = @_;
   my @child_accession = ();
   while (my $child = $rs->next)
   {
      my $child_term = $child->dbxref->accession;
      push @child_accession, $child_term 
         		         if $$PO_term_to_full_term_ref{$child_term};
   }
   return @child_accession;
}

__PACKAGE__->meta->make_immutable;
1;

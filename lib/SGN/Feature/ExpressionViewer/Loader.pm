package SGN::Feature::ExpressionViewer::Loader;
use Moose;
use XML::Twig;
use Bio::Chado::Schema::Cv;
use Bio::Chado::Schema;
use CXGN::GEM::Schema;
use CXGN::GEM::Expression;
use CXGN::GEM::Template;
use CXGN::GEM::Experiment;

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1);
has 'config_file_name' => (isa => 'Str', is => 'ro', required => 1);
has 'template_list' => (isa => 'ArrayRef[Str]', is => 'ro', 
			   traits => ['Array'],
 				handlers => {note_template => 'push'});
has 'img_name_to_src' => (isa => 'HashRef[Str]', is => 'ro',
			     traits => ['Hash'], 
				handlers => {img_list => 'keys'}); 
has 'img_info' => (isa => 'HashRef', is => 'ro', 
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
   $self->template_list = [];
   my $t = XML::Twig->new(twig_handlers => 
			  {
			     'template_name' => sub {$self->note_template( 
							      $_->text_only);},
			     'img_info' => sub{_get_info_about_img(@_, $self);} 
			  });
   $t->parsefile($self->config_file_name);
   $t->purge;
   $self->img_info;
}

#Parses and extracts information about image in XML file
sub _get_info_about_img
{
   my ($t, $section, $self) = @_;
   my $img_name = $section->first_child_text('img_name');
   $self->img_name_to_src{$img_name} = $section->first_child_text('img_src'); 
   my (@PO_term_order, %PO_term_to_color, 
		   		%PO_term_location, %coord_to_link);
   my $cxgn_exp_obj = CXGN::GEM::Experiment->new_by_name($self->schema);
   while (my $exp = $section->next_sibling('exp'))
   {
      my $exp_name = $exp->first_child_text('name');
      $cxgn_exp_obj->set_experiment_name($exp_name);
      my $exp_id = $cxgn_exp_obj->get_experiment_id;
      while (my $PO_term_info = $exp->next_sibling('PO_term_info'))
      {
         my $PO_term = $exp_id . $PO_term_info->first_child_text('term');
	 push @PO_term_order, $PO_term;
	 $PO_term_to_color{$PO_term} = 
				$PO_term_info->first_child_text('color');
	 my @color_coord = $PO_term_info->children_text('pixel');
         $PO_term_location{$PO_term} = \@color_coord;
         my @area_coord = $PO_term_info->children_text('coord');
	 $coord_to_link->{join('#', @area_coord)} =
		  		$PO_term_info->first_child_text('link');
	 $t->purge;
      }
      $t->purge;
   }
   $self->img_info->{$img_name} = [\%PO_term_to_color, 
				      \%PO_term_location, \%coord_to_link];
   $t->purge;
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
   my ($self, $img_name, $template_name) = @_;
   my $full_picture_PO_terms_ref = ${$self->img_info->{$img_name}}[0];
   my (%data, %full_term_to_PO_term) = 
	$self->assign_data_to_terms($template_name, 
				        keys $full_picture_PO_terms_ref);
   my ($PO_terms_child_ref, $PO_term_order_ref) = 
	$self->_get_PO_terms_child_and_order(\%PO_term_to_full_term,
						 \%full_term_to_PO_term); 
   my %PO_term_exists_in_picture = map {$_ => 1} 
				      keys %$full_picture_PO_terms_ref;
   my %full_PO_terms_child = 
	_match_PO_terms_with_children($PO_terms_child_ref,
					\%PO_term_exists_in_picture);
   return \%data, \%full_PO_terms_child, $PO_term_order_ref,
	     			    $full_picture_PO_terms_ref,
		                       ${$self->img_info->{$img_name}}[1],
	                                  ${$self->img_info->{$img_name}}[2];
}

sub assign_data_to_terms
{
   my ($self, $template_name, @PO_terms_list_ref) = @_;
   my $temp_template =
        CXGN::GEM::Template->new_by_name($self->$schema, $template_name);
   my $temp_expr =
        CXGN::GEM::Expression->$temp_template->new($self->schema,
                                        $temp_template->get_template_id);
   my %experiments = $temp_expr->get_experiment;
   my (%data, %PO_term_to_full_term);
   for my $term (@$PO_terms_list_ref)
   {
      my ($exp_id, $PO_term) = ($1, $2) if $term =~ /(\d*)(PO\d*)/;
      if ($PO_term_to_full_term{$PO_term})
      {
         #Works because of closure in Perl
         push @{$PO_term_to_full_term{$PO_term}}, $term;
      }
      else
      {
         $PO_terms_childs_ref{$PO_term} = [$term];
      }
      $data{$term} = ${$experiments{$exp_id}}{'median'};
   }
   return \%data, \%PO_term_to_full_term;
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
   my ($self, $PO_term_to_full_term_ref, $full_term_to_PO_term_ref) = @_;
   my $PO_terms_childs_ref = {};
   my $PO_term_order_ref = [];
   my $root_cv = 
	 $self->schema->resultset('General::Dbxref')->find(
		 {accession => (pop $self->data_PO_terms)})->cv_term->root;
   my ($PO_terms_childs_ref, $order_ref) = 
       $self->_update_PO_terms_childs($PO_terms_childs_ref, $PO_cv_term, 
					 $PO_term_to_full_term_ref,
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
 				 	      $PO_cv_term, 
						$PO_term_to_full_term_ref,
								 $order_ref);
      }
   }
   $PO_terms_childs_ref;
}

#Updates PO_terms_child
sub _update_PO_terms_childs
{
   my ($self, $PO_terms_childs_ref, $cv_term, $PO_term_to_full_term_ref, 
							$order_ref) = @_;
   my $accession = $cv_term->dbxref->accession;
   if (%$PO_term_to_full_term_ref{$accession})
   {
      push @{$order_ref}, @{%$PO_term_to_full_term_ref{$accession}};
      my @child_accession_list = 
	 _get_children_accession_from_rs($cv_term->recursive_children, 
						$PO_term_to_full_term_ref);
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

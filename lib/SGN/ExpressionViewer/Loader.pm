package SGN::ExpressionViewer::Loader;
use Moose;
use Config::General;
use Bio::Chado::Schema;
use CXGN::GEM::Schema;
use CXGN::GEM::Expression;
use CXGN::GEM::Template;
use CXGN::GEM::Experiment;
use File::Temp qw/ :seekable /;

$File::Temp::KEEP_ALL = 1;

has 'bcschema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1);
has 'cgschema' => (isa => 'CXGN::GEM::Schema', is => 'rw', required => 1);
has 'config_file_name' => (isa => 'Str', is => 'ro', required => 1);
has 'other_info_file_name' => (isa => 'Str', is => 'ro', required => 1);
has 'img_name_to_src' => (isa => 'HashRef[Str]', is => 'rw'); 
has 'img_info' => (isa => 'HashRef', is => 'rw', lazy => '1',
			traits => ['Hash'], handles => {img_list => 'keys'}, 
		          		builder => '_parse_config_file');

#Parse a config file using Config::General
#For the format, please see /conf/eFP_config.conf
sub _parse_config_file
{
   my $self = shift;
   my $other_info_hash_ref = $self->_process_other_info_needed;
   my $conf = new Config::General(-ConfigFile => $self->config_file_name,
				  -ForceArray => '1');
   my %config = $conf->getall;
   my (%tmp_img_name_to_src, %tmp_img_info, %PO_term_to_color,
                %PO_term_childs, @PO_term_order, %PO_term_location, 
                                       %coord_to_link, @order_of_coord);
   for my $img_name (keys %config)
   {
      my $unsorted_img_info = $config{$img_name};
      $tmp_img_name_to_src{$img_name} = delete $$unsorted_img_info{'img_src'};
      my $PO_term_order_str = delete $$unsorted_img_info{'order'};
      $PO_term_order_str ? 
         (@PO_term_order = split(/,/, $PO_term_order_str)) :
             				                (@PO_term_order = ());
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
			           $$other_info_hash_ref{$img_name}->{'child'},
				   $$other_info_hash_ref{$img_name}->{'order'}, 
			             \%PO_term_location, \%coord_to_link,
					 		      \@order_of_coord];
   }
   $self->img_name_to_src(\%tmp_img_name_to_src);
   \%tmp_img_info;
}

sub _process_other_info_needed
{
   my $self = shift;
   my %other_info_hash;
   open OTHER_INFO, "<", $self->other_info_file_name;
   while (<OTHER_INFO>)
   {
      chomp;
      my @entries = split /\t/;
      my $img_name = $entries[0];
      if ($entries[1] eq 'c')
      {
	 my $child_ref = [];
	 my $PO_term = $entries[2];
	 if ($entries[3])
	 {
	    my @child_list = split(/,/, $entries[3]);
	    $child_ref = \@child_list;
	 }
         $other_info_hash{$img_name}{'child'}{$PO_term} = $child_ref;
      }
      else
      {
	 my $order_str = $entries[2];
	 my @order = split(/,/, $order_str);
	 $other_info_hash{$img_name}{'order'} = \@order; 
      }
   }
   close OTHER_INFO; 
   return \%other_info_hash;
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
   my $other_needed_ref = $self->img_info->{$img_name};
   return $data_ref, $exp_PO_guide_ref, @$other_needed_ref; 
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
	      $experiments{$exp_id}{'mean'};
      my @targets = $cxgn_exp_obj->get_target_list();
      my @PO_term_included = ();
      for my $target (@targets) 
      {
         my @samples = $target->get_sample_list();
         for my $sample (@samples) 
         {
	     my %dbxref_po = $sample->get_dbxref_related('PO');
	     for my $dbxref_id (keys %dbxref_po) 
	     {
                 my %PO_info_hash = %{$dbxref_po{$dbxref_id}};
                 #push @PO_term_included, $PO_info_hash{'cvterm.name'};
                 push @PO_term_included, 
			'PO' . $PO_info_hash{'dbxref.accession'};
	     }
         } 
     }
     #my @PO_terms = keys %PO_term_included;
     my %PO_terms_uniq_hash = map{$_ => 1} @PO_term_included;     
     @PO_term_included = keys %PO_terms_uniq_hash;
     $exp_to_PO_terms{$exp_id} = \@PO_term_included;
   }
   return \%data, \%exp_to_PO_terms;
}

#Uses Bio::Chado::Schema to find the order of terms and their children
sub store_PO_term_childs_and_order_in_conf_file
{
   my $self = shift;
   #my $conf = new Config::General(-ConfigFile => $self->config_file_name,
                                  #-ForceArray => '1');
   #my %config = $conf->getall;
   my $PO_term_childs_for_img_ref = {};
   my $PO_term_order_for_img_ref = {};
   my %PO_term_to_img; 
   for my $img_name ($self->img_list)
   {
      my @list_of_picture_PO_terms = 
	   $self->get_list_of_all_PO_terms_in_picture($img_name);
      for my $PO_term (@list_of_picture_PO_terms)
      {
         $PO_term_to_img{$PO_term} ? 
	    (push @{$PO_term_to_img{$PO_term}}, $img_name) : 
	       ($PO_term_to_img{$PO_term} = [$img_name]);
         $$PO_term_childs_for_img_ref{$img_name}{$PO_term} = [];
         $$PO_term_order_for_img_ref{$img_name} = [];
      }
   }
   #my $config_ref = \%config;
   my $root_cv;
   for my $term (keys %PO_term_to_img)
   {
      my $term_accession = $1 if $term =~ /PO(\d*)/;
      my $dbxref_id = $self->bcschema->resultset('General::Db')->search_rs(
           {name => 'PO'})->search_related(
              'dbxrefs', {accession => $term_accession})->get_column(
                                                	'dbxref_id')->first;
      my $temp_cv = $self->bcschema->resultset('Cv::Cvterm')
                      ->search_rs({dbxref_id => $dbxref_id})->first;
      if ($temp_cv)
      {
         $root_cv = $temp_cv->root;
         last;
      }
   }
   my @child_cv_list = ($root_cv);
   my %has_been_called = ();
   for my $cv (@child_cv_list)
   {
      if ($cv eq 'done')
      {
	 %has_been_called = ();
      }
      else
      {
	 my $dbxref = $cv->dbxref_id;
	 unless ($has_been_called{$dbxref})
	 {
	    ($PO_term_childs_for_img_ref, $PO_term_order_for_img_ref) = 
               $self->_update_PO_term_childs_and_order_in_config(
	          $PO_term_childs_for_img_ref, $PO_term_order_for_img_ref,
						       $cv, \%PO_term_to_img);
	    @child_cv_list = (@child_cv_list, 'done', $cv->direct_children);
	    $has_been_called{$dbxref} = 1;
	 }
      }
   }
   $self->_write_other_needed_info($PO_term_childs_for_img_ref, 
				     $PO_term_order_for_img_ref);
}

#Updates PO_terms_child and order
sub _update_PO_term_childs_and_order_in_config
{
   my ($self, $PO_term_childs_for_img_ref, 
          $PO_term_order_for_img_ref, $cv_term, $PO_term_to_img_ref) = @_;
   my $accession = 'PO' . $cv_term->dbxref->accession;
   my $list_of_imgs_term_is_present_ref = $$PO_term_to_img_ref{$accession}; 
   if ($list_of_imgs_term_is_present_ref)
   {
      my $children_terms_rs = $cv_term->recursive_children;
      my $child_ref =  
	  $self->_get_children_accession_from_rs(
		    $children_terms_rs, $PO_term_to_img_ref);
      for my $img (@$list_of_imgs_term_is_present_ref)
      { 
         my @img_PO_term_order = @{$$PO_term_order_for_img_ref{$img}};
         my %PO_term_exist = map{$_ => 1} @img_PO_term_order;
         unless($PO_term_exist{$accession})
         {
            push @{$$PO_term_order_for_img_ref{$img}}, $accession; 
         }
         my @list_of_child_terms  = 
	    (@{$$PO_term_childs_for_img_ref{$img}{$accession}}, @$child_ref);
	 my %unique = map{$_ => 1} @list_of_child_terms;
	 my @unique_child = keys %unique;
	 $child_ref = \@unique_child;
         $$PO_term_childs_for_img_ref{$img}{$accession} = $child_ref; 
      }
   }
   return ($PO_term_childs_for_img_ref, $PO_term_order_for_img_ref);
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
   my %unique = map {$_ => 1} @child_accession;
   my @unique_child_accession = keys %unique;
   return \@unique_child_accession;
}

sub _write_other_needed_info
{
   my ($self, $PO_term_childs_for_img_ref, $PO_term_order_for_img_ref) = @_;
   my $fh = File::Temp->new(SUFFIX=>'.txt');
   for my $img (keys %$PO_term_order_for_img_ref)
   {
      map{print $fh "$img\tc\t$_\t" . 
             join(',', @{$$PO_term_childs_for_img_ref{$img}{$_}}) . "\n"} 
	                          keys %{$$PO_term_childs_for_img_ref{$img}}; 
      print $fh "$img\to\t" . 
                   join(',', @{$$PO_term_order_for_img_ref{$img}}) . "\n";

   }
   close $fh;
}

__PACKAGE__->meta->make_immutable;
1;

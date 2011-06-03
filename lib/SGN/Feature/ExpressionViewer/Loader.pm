package SGN::Feature::ExpressionViewer::Loader;
use Moose;
use Bio::Chadow::Schema::Cv;

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1,
		   trigger => sub {my $self = shift;
			           $self->PO_terms_childs(
					$self->_build_PO_terms_childs);});
has 'gene_config_file_name' => (isa => 'Str', is => 'rw', required => 1,
			  trigger => sub {shift->_parse_gene_config_file;});
has 'PO_term_to_color' => (isa => 'HashRef', is => 'ro');
has 'coordinates_to_link' => (isa => 'HashRef', is => 'ro',
                                builder => '_parse_gene_config_file');
has 'data_source' => (isa => ' ', is => 'rw', required => 1, 
			trigger => sub {$my $self = shift; 
					$self->data($self->_build_data);
					$self->PO_terms_childs( 
					   $self->_build_PO_terms_childs);});
has 'data' => (isa => 'HashRef', is => 'rw', lazy_build => 1, 
	         traits => ['Hash'], handles => {data_PO_terms => 'keys'});
has 'PO_term_order' => (isa => 'ArrayRef', is => 'rw',
		traits => ['Array'], handles => {note_next_PO_term => 'push'});
has 'PO_terms_childs' => (isa => 'HashRef', is => 'rw', lazy_build => 1);

#Config file should have this format:
#PO term\tColor RGB value and include data\tCoordinate on map\tLink
#Ex: PO00001\t0,0,26,1\t22,33\thttp://www.plant.com/
#Includes data from data_source
#Ex: PO00003\t0,0,24,0\t22,50\thttp://www.plant.com/
#Does not include data from data_source
sub _parse_gene_config_file
{
   my $self = shift;
   open CONFIG, "<", $self->gene_config_file_name;
   $self->PO_term_to_color({});
   $self->coordinates_to_link({});
   while (<CONFIG>)
   {
       #Removes all whitespace except \t
       chomp;
       $line =~ s/ //g;

       #Default is split("\t", $_)
       $entries = split;

       $entries[1] =~ s/\s//g;
       $entries[2] =~ s/\s//g;
       $self->PO_term_to_color->{$entries[0]} = $entries[1];
       $self->coordinates_to_link->{$entries[2]} = $entries[3];
   }
   $self->coordinates_to_link;
}

sub _build_data
{
   my $self = shift;
   
}

sub _build_PO_terms_childs
{
   my $self = shift;
   $PO_terms_childs_ref = {};
   $self->PO_term_order([]);
   my $root_cv = 
	 $self->schema->resultset('General::Dbxref')->find(
		 {accession => (pop $self->data_PO_terms)})->cv_term->root;
   my $PO_terms_childs_ref = 
       $self->_update_PO_terms_childs($PO_terms_childs_ref, $PO_cv_term);
   my @PO_terms = ($root_cv->direct_children);
   for my $rs (@PO_terms)
   {
      last if (scalar keys %$PO_terms_childs_ref ==
			      scalar $self->data_PO_terms); 
      while (my $PO_cv_term = $rs->next)
      {
	 last if (scalar keys %$PO_terms_childs_ref ==
				 scalar $self->data_PO_terms); 
         @PO_terms = (@PO_terms, $PO_cv_term->direct_children);
         $PO_terms_childs_ref = 
	    $self->_update_PO_terms_childs($PO_terms_childs_ref,
 				 	               $PO_cv_term);
      }
   }
   $PO_terms_childs_ref;
}

sub _update_PO_terms_childs
{
   my ($self, $PO_terms_childs_ref, $cv_term) = @_;
   my $accession = $cv_term->dbxref->accession;
   if ($self->data->{$accession})
   {
      $self->note_next_PO_term($accession);
      my @child_accession_list = _get_children_accession_from_rs($root_cv->recursive_children);
      $PO_terms_childs->{$accession} = \@child_accession_list;
   }
   return $PO_terms_childs_ref;
}

 #my %PO_terms_to_cv = ();
   #my %child_term_included = ();
   #my %PO_terms_childs = map{$_ => []}, $self->data_PO_terms;
   #my @PO_term_order = ();
   #my @children = ();
   #for my $term ($self->data_PO_terms)
   #{
      #my $child_cv = 
         #$self->schema->resultset('General::Dbxref')->find(
			#{accession=>$term})->cv_term;
      #$PO_terms_to_cv{$term} = $child_cv;
      #@children = (@children, 
		      #$self->_get_children_accession_from_rs($child_cv));
   #}
   #%children_term_in_picture = map{$_ => 1} @children;
      #{
            #push @PO_term_order, $accession;
         #}
         #elsif ($children_term_in_picture->{$accession})
         #{
            #for my $term (reverse @PO_term_order)
            #{
               #if ($self->schema->resultset("Cv::CvtermRelationship")->search(
		               #[object_id = $PO_terms_to_cv{$term}->cvterm_id, 
		                      #subject_id = $PO_cv_term->cvterm_id]))
               #{
                  #$PO_terms_childs{$term} =
			#[@{$PO_terms_childs{$term}}, $accession];
		  #break; 
               #}
            #}
         #}
  #for my $term (keys $self->data)
   #{
      #Finds PO_terms' child
      #my @PO_terms_childs_list
      #my $children_rs = $self->schema->resultset('General::Dbxref')->find({accession=>"$term"})->cv_term->recursive_children;
      #while ()
      #for (my $i = 0; $i < scalar @PO_terms_childs_list; $i++)
      #{
         my $child = $PO_terms_childs_list[$i]; 
         if ($self->PO_term_to_color{$child_term} 
		    && !($self->data{$child_term}))
         #{
            @PO_terms_childs_list = (@PO_terms_childs_list, 
         #}
         #else
         #{
            splice($PO_terms_childs_list, $i, 1);
            #$i--;
         #}    
      #}
      #$self->PO_terms_childs->{$term} = \@PO_terms_childs_list;
   #}

sub _get_children_accession_from_rs
{
   my ($self, $rs) = @_;
   my @child_accession = ();
   while (my $child = $rs->next)
   {
      my $child_term = $child->dbxref->accession;
      push @child_accession, $child_term 
         		         if $self->PO_term_to_color->{$child_term};
   }
   return @child_accession;
}

__PACKAGE__->meta->make_immutable;
1;

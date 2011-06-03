package SGN::Feature::ExpressionViewer::Analyzer;
use Moose;
use SGN::Feature::ExpressionViewer::Converter;
use SGN::Feature::ExpressionViewer::Colorer;

has 'image_source' => (isa => 'Str', is => 'rw', required => 1);
has 'data' => (isa => 'HashRef[Str]', is => 'rw', required => 1, 
	       trigger => sub{my $self = shift;
			      my ($e_data_ref, $c_data_ref) =
			         $self->_parse_data_from_data_ref($self->data);
		              $self->converter->gene_signal_in_tissue(
							        $e_data_ref);
			      $self->converter->control_signal_for_tissue(
								$c_data_ref);
			     });
has 'compare_data' => (isa => 'HashRef[Str]', is => 'rw', default => sub {{}},
		       trigger => sub{my $self = shift;
		                      my ($e_data_ref, $c_data_ref) =
		                         $self->_parse_data_from_data_ref(
					                         $self->data);
		       		      $self->converter->
					 gene_signal_in_tissue(
							     $e_data_ref);
		       		      $self->converter->
				         control_signal_for_tissue(
                                                             $c_data_ref);
				     });
has 'PO_term_to_color' => (isa => 'HashRef[Str]', is => 'rw', 
			     required => 1, traits => ['Hash'], 
			       handles => {picture_PO_terms => 'keys'});  
has 'PO_term_order' => (isa => 'ArrayRef[Str]', is => 'rw', required=>1);
has 'PO_terms_childs' => (isa => 'HashRef[ArrayRef]', is => 'rw', required => 1);
has 'PO_terms_not_shown' => (isa => 'ArrayRef[Str]', is => 'rw',
			       traits => ['Array'], 
			          handles => {note_term_not_shown => 'push'});
has 'converter' => (isa => 'SGN::Feature::ExpressionViewer::Converter', 
						is => 'rw', lazy_build => 1);
has 'compare_converter' => (isa => 'SGN::Feature::ExpressionViewer::Converter',
 				is => 'rw', lazy_build => 1); 
has 'colorer' => (isa => 'SGN::Feature::ExpressionViewer::Colorer', 
		     			        is => 'ro', lazy_build => 1);
sub _build_converter
{
   my $self = shift;
   my ($e_data_ref, $c_data_ref) =
		$self->_parse_data_from_data_ref($self->data);
   SGN::Feature::ExpressionViewer::Converter->new(
	      'gene_signal_in_tissue'=> $e_data_ref,
		 'control_signal_for_tissue'=> $c_data_ref);
}

sub _build_compare_converter
{
   my $self = shift;
   my ($e_data_ref, $c_data_ref) =
		$self->_parse_data_from_data_ref($self->compare_data);
   SGN::Feature::ExpressionViewer::Converter->new(
	      'gene_signal_in_tissue'=> $e_data_ref,
		 'control_signal_for_tissue'=> $c_data_ref);
}

#Data hash should have this form: PO_term -> exp data,control data
sub _parse_data_from_data_ref
{
   my ($self, $data_ref) = @_;
   my %data_hash = %$data_ref;
   my (%experiment_data, %control_data);
   for my $PO_term (keys %data_hash)
   {
       my @data_sep = split(/,/,$data_hash{$PO_term});
       $experiment_data{$PO_term} = $data_sep[0];
       $control_data{$PO_term} = $data_sep[1];
   }
   return (\%experiment_data, \%control_data);
}

sub _build_colorer
{
   SGN::Feature::ExpressionViewer::Colorer->new('image_source'=>shift->image_source );
}

sub make_absolute_picture
{
   my ($self, $threshold, $override, $mask_ratio, $grey_mask_on) = @_;
   $self->colorer->reset_image;
   my ($color_conversion_table, $min_color_ref, $max_color_ref, $max) = 
	 $self->converter->calculate_absolute($threshold, $override, 
					         $grey_mask_on, $mask_ratio); 
   $self->__change_image($color_conversion_table);
   $self->_get_absolute_legend_outline($self->converter->get_min, $max, 
					   $min_color_ref, $max_color_ref); 
}

sub make_relative_picture
{
   my ($self, $threshold, $override, $mask_ratio, $grey_mask_on) = @_;
   $self->colorer->reset_image;
   my ($color_conversion_table, $min_color_ref, $max_color_ref) = 
	 $self->converter->calculate_relative($threshold, $override, 
					         $grey_mask_on, $mask_ratio); 
   $self->__change_image($color_conversion_table);
   $self->_get_relative_legend_outline($self->converter->get_min, $max, 
					   $min_color_ref, $max_color_ref);
}

sub make_comparison_picture
{
   my ($self, $threshold, $override, $mask_ratio, $grey_mask_on) = @_;
   $self->colorer->reset_image;
   my ($color_conversion_table, $min_color_ref, $max_color_ref, $min, $max) = 
      SGN::Feature::ExpressionViewer::Converter->calculate_comparison(
         $self->converter, $self->compare_converter, $threshold, 
				   $override, $grey_mask_on, $mask_ratio);   
   $self->__change_image($color_conversion_table);
   $self->_get_relative_legend($min, $max, $min_color_ref, $max_color_ref);
}

sub __change_image
{
   my ($self, $color_conversion_table) = @_;
   $self->PO_terms_not_shown([]);
   my %color_of_picture_PO_terms = map{$_  => [255,255,255]} 
				      $self->picture_PO_terms;
   for my $PO_term (@{$self->PO_term_order})
   {
     
      my $converted_color = $color_conversion_table->{$PO_term};
      if ($color_of_picture_PO_terms{$PO_term})
      {
         $color_of_picture_PO_terms{$PO_term} = $converted_color; 
      }
      else
      {
         $self->note_term_not_shown($PO_term);
      }
      for my $child_term (@{$self->PO_terms_childs->{$PO_term}})
      {
	 if ($color_of_picture_PO_terms{$child_term})
	 {
            $color_of_picture_PO_terms{$child_term} = $converted_color;
	 }
      }
   }
   for my $term (keys %color_of_picture_PO_terms)
   {
       my $current_color = $self->PO_term_to_color->{$term}; 
       $self->colorer->changeColorIndex(split(/,/, $current_color),
			         @{$color_of_picture_PO_terms{$term}});
   }
}

#Returns a hash_ref with expression levels as keys, colors as values
#to be used to build a legend for an absolute image
sub _get_absolute_legend_outline
{
   my ($self, $min, $max, $threshold, $min_colors, $max_colors) = @_;
   my %outline = ();
   my $numInc = 9;  
   
   #Assumes for absolute data we changed the green intensity of RGB
   my $colorInc = ($$max_colors[1] - $$min_colors[1])/$numInc;
   my $inc = ($max - $min)/$numInc;
   for my $i (1..$numInc)
   {
      my $label = sprintf("%.2f", $max - $i * $inc);
      $outline{$sprintf("%.2f", $max - $i * $inc)} = 
		"255," . floor($$max_colors[1] - $i * $colorInc + .5) . ",0";
   }
   $max = "${max}+" if $max == $threshold;
   $outline{$max} = join(",", @$max_colors); 
   return \%outline;
}

sub _get_relative_legend_outline
{
   my ($self, $min, $max, $threshold, $min_colors, $max_colors) = @_;
   my %outline = ();

   #Assumes those above median have green modified and those below have
   #yellow modified from zero
   my $numInc = 9;
   my $colorInc = $$min_colors[2];
   if ($max >= $self->converter->get_median)
   {
       $colorInc += 255 - $$max_colors[1];
   }
   else
   {
       $colorInc -= $$max_colors[2];
   }
   $colorInc /= $numInc;
   my $inc = ($max - $min)/$numInc;
   for my $i (1..$numInc)
   {
      my $label = sprintf("%.2f", $max - $i * $inc);
      my $greenChange = floor($$max_colors[1] + $i * $colorInc + .5);
      if ($max >= $self->converter->get_median and $greenChange < 255)
      {
         $outline{sprintf("%.2f", $max - $i * $inc)} = "255,$greenChange,0";
      }
      else
      {
         my $colorShift = abs($greenChange - 255);
         $outline{sprintf("%.2f", $max - $i * $inc)} = 
	     (255 - $colorShift) . "," . (255 - $colorShift) . ",$colorShift";
      }
   }
   $max = "${max}+" if $max == $threshold;
   $outline{$max} = join(",", @$max_colors); 
   return \%outline;
}

__PACKAGE__->meta->make_immutable;
1;

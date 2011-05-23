package SGN::Feature::ExpressionViewer::Analyzer;
use Moose;
use SGN::Feature::ExpressionViewer::Converter;
use SGN::Feature::ExpressionViewer::Colorer;

has 'image_source' => {isa => 'Str', is => 'rw', required => 1};
has 'data' => {isa => 'Hash', is => 'rw', required => 1};
has 'compare_data' => {isa => 'Hash', is => 'rw', default=>'()'};
has 'gene_config_file_name' => {isa => 'Str', is => 'ro', required => 1};
has 'PO_term_to_color' => {isa => 'Hash', is => 'ro'};  
has 'coordinates_to_link' => {isa => 'Hash', is => 'ro', 
				builder => '_parse_gene_config_file'};
has 'PO_term_children' => {isa => 'Hash', is => 'ro'};
has 'converter' => {isa => 'SGN::Feature::ExpressionViewer::Converter', 
						is => 'rw', lazy_build => 1};
has 'compare_converter' => {isa => 'SGN::Feature::ExpressionViewer::Converter', 				is => 'rw', lazy_build => 1}; 
has 'colorer' => {isa => 'SGN::Feature::ExpressionViewer::Colorer', 
							lazy_build => 1};
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

sub _build_converter
{
   my $self = shift;
   my %data_hash = $self->data;
   $self->_build_converter_from_data_ref(\%data_hash);
}

sub _build_compare_converter
{
   my $self = shift;
   $self->_build_converter_from_data_ref(\$self->compare_data);
}

sub _build_converter_from_data_ref
{
   my ($self, $data_ref) = @_;
   my %data_hash = %$data_ref;
   my (%experiment_data, %control_data);
   for my $PO_term (keys $self->PO_term_to_color)
   {
       my $color = $self->PO_term_to_color->{$PO_term};
       if ($color =~ m/,1$/)
       {
          my @data_sep = split($data_hash{$PO_term});
          $experiment_data{$PO_term} = $data_sep[0];
          $control_data{$PO_term} = $data_sep[1];
          #gets terms
          
          $self->PO_term_children->{$PO_term} = ();
          for my $child_term ()
          {
             push($self->PO_term_children->{$PO_term}, $child_term)
	        
          }
       }
   }
   SGN::Feature::ExpressionViewer::Converter->new(
              'gene_signal_in_tissue'=>"%experiment_data",
                 'control_signal_for_tissue'=>"%control_data");
}

sub _build_colorer
{
   SGN::ExpressionViewer::Colorer->new('image_source'=>shift->image_source );
}

after 'set_image_source' => sub {
   my $self = shift;
   $self->colorer = $self->_build_colorer;
};

after 'set_data' => sub {
   my $self = shift;
   $self->converter = $self->_build_converter;
};

after 'set_compare_data' => sub {
   my $self = shift;
   $self->compare_converter = $self->_build_compare_converter;
};

sub make_absolute_picture
{
   my ($self, $threshold, $override, $grey_mask_on, $mask_ratio) = @_;
   $colorer->reset_image;
   my ($color_conversion_table, $min_color_ref, $max_color_ref) = 
	 $self->converter->calculate_absolute($threshold, $override, 
					         $grey_mask_on, $mask_ratio)}; 
   $self->__change_image($color_conversion_table);
   $self->colorer->draw_absolute_legend($self->converter_get_min_and_max(), 
					   $min_color_ref, $max_color_ref,
					       $threshold); 
}

sub make_relative_picture
{
   my ($self, $threshold, $override, $grey_mask_on, $mask_ratio) = @_;
   $colorer->reset_image;
   my ($color_conversion_table, $min_color_ref, $max_color_ref) = 
	 $self->converter->calculate_relative($threshold, $override, 
					         $grey_mask_on, $mask_ratio)}; 
   $self->__change_image($color_conversion_table);
   $self->colorer->draw_relative_legend($self->converter_get_min_and_max(), 
					   $min_color_ref, $max_color_ref,
					       $threshold);
}

sub make_comparison_picture
{
   my ($self, $threshold, $override, $grey_mask_on, $mask_ratio) = @_;
   $colorer->reset_image;
   $self->compare_converter = $self->__build_converter;
   my ($color_conversion_table, $min_color_ref, $max_color_ref, $min, $max) = 
      SGN::Feature::ExpressionViewer::Converter->calculate_comparison(
         $self->converter, $self->compare_converter, $threshold, 
				   $override, $grey_mask_on, $mask_ratio);   
   $self->__change_image($color_conversion_table);
   $self->colorer->draw_relative_legend($min, $max, $min_color_ref, 
					   $max_color_ref, $threshold);
}

sub __change_image
{
   my ($self, $color_conversion_table) = @_;
   for my $PO_term (keys %$color_conversion_table)
   {
      my $converted_color = $$color_conversion_table{$PO_term};
      my $current_color = $self->PO_term_to_color->{$PO_term};
      $current_color =~ s/,e|c,1$//;
      $self->colorer->changeColorIndex(split($current_color,','),
					                  @$converted_color);
      #gets related terms as an array

      for my $child_term ($children_terms)
      {
         $child_term_color = $self->PO_term_to_color{$child_term};
         if ($child_term_color =~ s/,0$//)
         {
            $self->colorer->changeColorIndex(split($child_term_color, ','), 
					   	          @$converted_color);
         }
      }
   }
}

__PACKAGE__->meta->make_immutable;
1;

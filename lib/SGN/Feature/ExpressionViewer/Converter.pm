package SGN::Feature::ExpressionViewer::Converter;
use Moose;
use Statistics::Descriptive;
use POSIX;

has 'gene_signal_in_tissue' => (isa => 'HashRef[Num]', is => 'rw', 
			         required => 1, traits => ['Hash'], 
				   handles => {tissues => 'keys',
					       exp_levels => 'values'});
has 'stats_obj' => (isa => 'Statistics::Descriptive::Full', is => 'rw', 
		       lazy_build => 1, handles => {get_min => 'min',
						    get_median => 'median',
						    get_mean => 'mean',
						    get_max => 'max'});
has 'control_signal_for_tissue' => (isa => 'HashRef[Num]', is => 'rw', 
				     required => 0, traits => ['Hash'],
				      handles => {control_levels => 'values'});

#Creates the stats object
sub _build_stats_obj
{
   return Statistics::Descriptive::Full->new();
}

#Calculates color representation of each tissue according to its 
#signal strength
#User can specify a $threshold, whether to mask and the ratio at which to do so
#Returns a hash ref with tissues as keys and an array ref holding colors
sub calculate_absolute
{
   my ($self, $threshold, $override, $grey_mask_on, $mask_ratio) = @_;   
   my %tissue_to_RGB_val;
   $self->_load_data_into_stats_obj($self->exp_levels);
   my $max = $self->_determine_max($threshold, $override);
   my $max_color_green_index = 255;
   my $min_color_green_index = 0;
   for my $tissue ($self->tissues)
   {
      my $signal = $self->gene_signal_in_tissue->{$tissue};
      if ($signal != 0 and $grey_mask_on and
	    $self->stats_obj->standard_deviation()/$signal > $mask_ratio)
      {
          $tissue_to_RGB_val{$tissue} = [221,221,221];
      }
      else
      {
          #255.5 is used for rounding purposes
          my $intensity = floor(255.5 - $signal * 255.0/$max);
          $intensity = ($intensity >= 0) ? $intensity:0;
          $min_color_green_index = $intensity 
			if $min_color_green_index < $intensity;
          $max_color_green_index = $intensity 
			if $max_color_green_index > $intensity;
          $tissue_to_RGB_val{$tissue}=[255, $intensity, 0];
      }
   }
   return \%tissue_to_RGB_val, [255, $min_color_green_index, 0],
                               [255, $max_color_green_index, 0], $max;
}

#Calculates color representation of each tissue according to the log base 2
#ratio of signal divided by control
#User can specify a $threshold, whether to mask and the ratio at which to do so
#Returns a hash ref with tissues as keys and an array ref holding colors
sub calculate_relative
{
   my ($self, $threshold, $override, $grey_mask_on, $mask_ratio) = @_;   
   my %tissue_to_ratio = $self->_get_ratio_between_control_and_mean();  
   $self->_load_data_into_stats_obj(values %tissue_to_ratio);
   my $median = $self->get_median;
   my $max = $self->_determine_max($threshold, $override);
   my $max_dif = $max - $median;
   my $abs_val_min_dif = abs($self->get_min - $median);
   #Sets $max to absolute value of min if it is greater than max
   $max_dif = ($max_dif > $abs_val_min_dif) ? $max_dif:$abs_val_min_dif;
   my ($max_color_index, $min_color_index) = (0,0);
   my %tissue_to_RGB_val = (); 
   foreach my $tissue (keys %tissue_to_ratio)
   {
      my $signal = $tissue_to_ratio{$tissue};

      #Sets $intensity to 255 if $signal > $threshold
      my $intensity = ($signal <= $max) ?  
		floor(($signal - $median)*255.0/$max_dif + .5):255;
      if ($signal != 0 and $grey_mask_on and
	    $self->stats_obj->standard_deviation()/$signal > $mask_ratio)
      {
          $tissue_to_RGB_val{$tissue} = [221,221,221];
      }
      elsif ($signal >= $median || $signal >= $max)
      {
          $max_color_index = $intensity if $max_color_index < $intensity 
	      						   and $max > $median;
          $tissue_to_RGB_val{$tissue} = [255, 255 - $intensity, 0];
      }
      else
      {
          $min_color_index = $intensity if $min_color_index > $intensity;
          $max_color_index = $intensity if $max < $median and 
		($max_color_index == 0 || $max_color_index < $intensity);
          $tissue_to_RGB_val{$tissue} = 
			[255 + $intensity, 255 + $intensity, - $intensity];
      }
   }
   my $max_color = [];
   if ($max_color_index >= 0)
   {
      $max_color = [255, 255 - $max_color_index, 0];
   }
   else
   {
      $max_color = [255 + $max_color_index, 255 + $max_color_index,
							-$max_color_index];
   }
   return \%tissue_to_RGB_val, 
     [255 + $min_color_index, 255 + $min_color_index, -$min_color_index],
        				   		  $max_color, $max;
}

#Calculates colors by comparing the log base 2 ratio of a gene's signal to
#its control to another gene's log base 2 ratio
#User can specify a $threshold, whether to mask and the ratio at which to do so
#Returns a hash ref with tissues as keys and an array ref holding colors
sub calculate_comparison
{
   my ($self, $comparison_converter, $threshold, 
		$override, $grey_mask_on, $mask_ratio) = @_;
   my %dif_in_gene_sig;
   my %dif_in_control_sig;
   for my $tissue ($self->tissues)
   {
      my $gene1Sig = $self->gene_signal_in_tissue->{$tissue};
      my $gene1Control = $self->control_signal_for_tissue->{$tissue};
      my $gene2Sig = $comparison_converter->gene_signal_in_tissue->{$tissue};
      my $gene2Control = $comparison_converter->control_signal_for_tissue->{$tissue};

      #If all are defined and not 0,
      if ($gene2Sig and $gene2Control and $gene1Sig and $gene1Control)
      {
         $dif_in_gene_sig{$tissue} = $gene1Sig/$gene2Sig;
         $dif_in_control_sig{$tissue} = $gene1Control/$gene2Control;
      }
   }
   my $temp_gene_analysis = 
	SGN::Feature::ExpressionViewer::Converter->new(
	   'gene_signal_in_tissue'=> \%dif_in_gene_sig,
	       'control_signal_for_tissue'=> \%dif_in_control_sig); 
   return ($temp_gene_analysis->calculate_relative($threshold, $grey_mask_on, 
							$override, $mask_ratio),	      $temp_gene_analysis->get_min, $temp_gene_analysis->get_median);
}

sub get_min_and_max
{
   my $self = shift;
   return ($self->stats_obj->min(), $self->stats_obj->max());
}

#Loads the data into the stats_obj
sub _load_data_into_stats_obj
{
   my ($self, @newData) = @_;
   $self->stats_obj(_build_stats_obj);
   $self->stats_obj->add_data(@newData);
}

#Returns true if threshold is defined, greater than the fifth percentile,
#and less than the max 
sub _threshold_is_valid
{
   my ($self, $threshold) = @_;
   my $fifth_percentile = $self->stats_obj->percentile(5);
   my $max = $self->stats_obj->max();
   return ($threshold and $threshold > $fifth_percentile 
				     and $threshold <= $max);
}

#Returns the max according to user specification if valid or user wants
#to override or by default to the maximum of the data value
sub _determine_max
{
   my ($self, $threshold, $override) = @_;
   if ($self->_threshold_is_valid($threshold) || $override)
   {
      return $threshold;
   }
   else
   {
      return $self->stats_obj->max;
   }
}

#Gets the log base 2 ratio between the signal and control 
sub _get_ratio_between_control_and_mean
{
   my $self = shift;
   my %tissue_to_ratio;
   for my $tissue ($self->tissues)
   {
      my $control_sig = $self->control_signal_for_tissue->{$tissue};
      my $gene_sig = $self->gene_signal_in_tissue->{$tissue};
      $tissue_to_ratio{$tissue} = log($gene_sig/$control_sig)/log(2) 
					if $control_sig != 0 and $gene_sig != 0;
   }
   return %tissue_to_ratio;
}

__PACKAGE__->meta->make_immutable;
1;

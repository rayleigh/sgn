package SGN::Feature::ExpressionViewer::Converter;
use Moose;
use Statistics::Descriptive;
use POSIX;

has gene_signal_in_tissue => {isa => 'Hash', is => 'rw', required => 1,};
has stats_obj => {isa => 'Statistics::Descriptive::Full', lazy_build => 1,};
has control_signal_for_tissue => {isa => 'Hash', is => 'rw', required => 0};
#has threshold => {isa => 'Int', is => 'rw', required => 1, default => 0,};
#has grey_mask => {isa => 'Bool', is => 'rw', required => 1, default => 0,};
#has override => {isa => 'Bool', is => 'rw', required => 1, default => 0,};

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
   $self->_load_data_into_stats_obj(values $self->gene_signal_in_tissue);
   my $max = $self->_determine_max($threshold, $override);
   my $max_color_green_index = 255;
   my $min_color_green_index = 0;
   foreach my $tissue (keys $self->gene_signal_in_tissue)
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
          $intensity ($intensity >= 0) ? $intensity:0;
          $min_color_green_index = $intensity 
			if $min_color_green_index < $intensity;
          $max_color_green_index = $intensity 
			if $max_color_green_index > $intensity;
          $tissue_to_RGB_val{$tissue}=[255, $intensity, 0];
      }
   }
   return \%tissue_to_RGB_val, [255, $min_color_green_index, 0],
                                       [255, $max_color_green_index, 0];
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
   my $median = $self->stats_obj->median();
   my $max_dif = $self->_determine_max($threshold, $override) - $median;
   my $abs_val_min_dif = abs($self->stats_obj->min - $median);
   #Sets $max to absolute value of min if it is greater than max
   my $max_dif = ($max_dif > $abs_val_min_dif) ? $max_dif:$abs_val_min_dif;
   my $max_color_index = 0;
   my $min_color_index = 0;
   foreach my $tissue (keys %tissue_to_ratio)
   {
      my $signal = $tissue_to_ratio{$tissue};
      #Sets $intensity to 255 if $signal > $threshold
      my $intensity = ($signal <= $threshold) ?  
		floor(($signal - $median)*255.0/$max_dif):255;
      if ($signal != 0 and $grey_mask_on and
	    $self->stats_obj->standard_deviation()/$signal > $mask_ratio)
      {
          $tissue_to_RGB_val{$tissue} = [221,221,221];
      }
      elsif ($signal > $median)
      {
          $max_color_index = $intensity if $max_color_index < $intensity;
          $tissue_to_RGB_val{$tissue} = [255, 255 - $intensity, 0];
      }
      else
      {
          $min_color_index = $intensity if $min_color_index > $intensity;
          $tissue_to_RGB_val{$tissue} = 
			[255 + $intensity, 255 + $intensity, - $intensity];
      }
   }
   return \%tissue_to_RGB_val, 
     [255 + $min_color_index, 255 + $min_color_index, -$min_color_index],
        				   [255, 255 - $max_color_index, 0];
}

#Calculates colors by comparing the log base 2 ratio of a gene's signal to
#its control to another gene's log base 2 ratio
#User can specify a $threshold, whether to mask and the ratio at which to do so
#Returns a hash ref with tissues as keys and an array ref holding colors
sub calculate_comparison
{
   my ($class, $gene1Expression, $gene2Expression, 
		  $threshold, $override, $grey_mask_on, $mask_ratio) = @_;
   my %dif_in_gene_sig;
   my %dif_in_control_sig;
   foreach my $tissue (keys $gene1Expression->gene_signal_in_tissue)
   {
      $gene1Sig = $gene1Expression->gene_signal_in_tissue{$tissue};
      $gene1Control = $gene1Expression->control_signal_for_tissue{$tissue};
      $gene2Sig = $gene2Expression->gene_signal_in_tissue{$tissue};
      $gene2Control = $gene2Expression->control_signal_for_tissue{$tissue};
      #If both gene2 signal and its control are defined and not 0,
      if ($gene2Sig and $gene2Control)
      {
         $dif_in_gene_sig{$tissue} = $gene1Sig/$gene2Sig;
         $dif_in_control_sig{$tissue} = $gene1Control/$gene2Control;
      }
   }
   my $dif_gene_analysis = 
	SGN::Feature::ExpressionViewer::Converter->new(
	   'gene_signal_in_tissue'=>"%dif_in_gene_sig",
	       'control_signal_for_tissue'=>"%dif_in_control_sig"); 
   return ($dif_gene_analysis->calculate_relative($threshold, $grey_mask_on, 
							$override, $mask_ratio),	      $dif_gene_analysis->get_min_and_max());
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
   $self->stats_obj->add_data(());
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
   foreach my $tissue (keys $self->gene_signal_in_tissue)
   {
      my $control_sig = $self->control_signal_for_tissue{$tissue};
      my $gene_sig = $self->gene_signal_in_tissue{$tissue};
      %tissue_to_ratio{$tissue} = log($gene_sig/$control_sig)/log(2) 
					if $control_sig != 0 and $gene_sig != 0;
   }
   return %tissue_to_ratio;
}

__PACKAGE__->meta->make_immutable;
1;

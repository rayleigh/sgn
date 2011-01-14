package SGN::Feature::ExpressionViewer::Colorer;
use Moose;
use GD::Image;

has 'image_source' => (isa => "Str", is => "ro", required => 1,);
has 'image' => (isa => "GD::Image", is => "ro", lazy_build => 1,);
#has 'tmp_directory' => (isa => "Str", is => "ro", default=>'/tmp');

sub _build_image
{
   GD::Image->new(shift->image_source);
}

#Converts an index of the given current RGB values to a new index
#of the given new RGB values
#Takes no action if index is not found or RGB values specify black or white. 
sub changeColorIndex
{
   my ($self, $red, $green, $blue, $new_red, $new_green, $new_blue) = @_;
   my $color_index = $self->image->colorExact($red, $green, $blue);

   #If color_index is found and neither RGB values reference black or white
   if ($color_index != -1 and 
	$self->_index_is_valid($red, $green, $blue, $new_red, $new_green, $new_blue))
   {
      $self->image->colorDeallocate($color_index);
      $self->image->colorAllocate($new_red, $new_green, $new_blue);
   }
}

#RGB values are valid if they do not specify white (255,255,255) 
#or black (0,0,0)
sub _index_is_valid
{
   my ($self, $red, $green, $blue, $new_red, $new_green, $new_blue) = @_;
   return !(($new_red == 0 and $new_green == 0 and $new_blue == 0) ||
		($new_red == 255 and $new_green = 255 and $new_blue == 255) ||
		    ($red == 0 and $green == 0 and $blue == 0) ||    
                        ($red == 255 and $green == 255 and $blue == 255)); 
}

#Writes the image in the outfile if specified or in the image source
#with _mod_PNG_img.png attached. 
sub writeImageAsPNGFile 
{
   my ($self, $file_name) = @_;
   unless ($file_name) 
   {
      $file_name = $self->image_source;
      $file_name =~ s/\..*?$/_mod_PNG_img\.png/;
   }
   #print STDERR "FILENAME=".$file_name."\n";
   open my $PNGFILE, ">", "$file_name" || die "Can't open file";
   my $png_data = $self->image->png();
   binmode $PNGFILE;
   print $PNGFILE $png_data;
   close $PNGFILE;
}

#Draws the legend for an absolute expression picture
sub drawAbsoluteLegend
{
   my ($self, $min, $min_colors, 
		$max, $max_colors, $maxGreaterThanThreshold) = @_;

   #Assumes for absolute data we changed the green intensity of RGB
   my $inc = ($$max_colors[1] - $$min_colors[1])/10;
   my @colors;
   for my $i (0..9)
   {
	$colors[$i] = [255, floor($$max_colors[1] - $i * $inc + .5), 0];
   }
   $self->_draw_legend($min, $max, \@colors, 
				'Absolute', $maxGreaterThanThreshold);
}

#Draws the legend for a relative expression picture
sub drawRelativeLegend
{
   my ($self, $min, $min_colors,
                $max, $max_colors, $maxGreaterThanThreshold) = @_;
   #Assumes those above median have green modified and those below have
   #yellow modified from zero
   my $inc = ($$max_colors[1] + $$min_colors[2])/10;
   my @colors;
   for my $i (0..9)
   {
      my $greenChange = floor($$max_colors[1] + $i * $inc + .5);
      if ($greenChange < 255)
      {
         $colors[$i] = [255, $greenChange, 0];
      }
      else
      {
         my $colorShift = $greenChange % 255;
         $colors[$i] = [255 - $colorShift, 255 - $colorShift, $colorShift]; 
      }
   }
   $self->_draw_legend($min, $max, \@colors,
                                'Ratio log2', $maxGreaterThanThreshold);   
}

#Given the min, max, title, and a reference to an array with the ten colors' RGB
#in the legend, draws the legend.
sub _draw_legend
{
   my ($self, $min, $max, $colors_list_ref, $title, 
				$maxGreaterThanThreshold) = @_;
   my $increment = ($min - $max)/10.0;
   for my $i (0..9)
   {
      my $color = $self->image->colorResolve(@$colors_list_ref[$i]);
      $self->image->filledRectangle(10*($i + 1), 10, 15*($i + 1), 20, $color);
      my $black = $self->image->colorResolve(0,0,0); 
      my $colorRepValue = sprintf("%.2f", $max - $i * $increment);
      $colorRepValue .= "+" if $maxGreaterThanThreshold and $i == 0;  
      $self->image->string('gdSmallFont', 10*($i+1) + 2, 21, $colorRepValue, $black);
   }   
}

__PACKAGE__->meta->make_immutable;
1;

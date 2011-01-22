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
    my $legend = new GD::Image(140, 50);
   #Sets the background of legend to white
   $legend->allocate(255,255,255);
   self->_draw_text($legend, 10, 10, 'gdMediumBoldFont', 'Absolute');
   #Assumes for absolute data we changed the green intensity of RGB
   my $colorInc = ($$max_colors[1] - $$min_colors[1])/9;
   my $numInc = ($max - $min)/9;
   for my $i (0..9)
   {
      my @coordinates = (20 + $i * 10, 10, 30 + $i * 10, 25);
      $self->_draw_rectangle($legend, @coordinates,  
					255, floor($$max_colors[1] - $i * $inc + .5), 0); 
      my $colorRepValue = sprintf("%.2f", $max - $i * $numInc);
      $colorRepValue .= "+" if $maxGreaterThanThreshold and $i == 0;
      #Puts the text in the vertical middle of the block and 3 away horizontally to the right
      $self->_draw_text($legend, ($coordinates[0] + $coordinates[2])/2, $coordinates[3] + 3,
                                             		       'gdSmallFont', $colorRepValue); 
   }
   $self->_combine_image_and_legend($legend);
}

#Draws the legend for a relative expression picture
sub drawRelativeLegend
{
   my ($self, $min, $min_colors,
                $max, $max_colors, $maxGreaterThanThreshold) = @_;
   my $legend = new GD::Image(140, 50);
   #Sets the background of legend to white
   $legend->allocate(255,255,255);
   self->_draw_text($legend, 10, 10, 'gdMediumBoldFont', 'Ratio log2');
   #Assumes those above median have green modified and those below have
   #yellow modified from zero
   my $colorInc = (255 - $$max_colors[1] + 255 - $$min_colors[2])/9;
   my $numInc = ($max - $min)/9;
   for my $i (0..9)
   {
      my $greenChange = floor($$max_colors[1] + $i * $colorInc + .5);
      my @coordinates = (20 + $i * 10, 10, 30 + $i * 10, 25);
      if ($greenChange < 255)
      {
         $self->_draw_rectangle($legend, @coordinates, 255, $greenChange, 0); 
      }
      else
      {
         my $colorShift = $greenChange % 255;
         $self->_draw_rectangle($legend, @coordinates, 
				    255 - $colorShift, 255 - $colorShift, $colorShift); 
      }
      my $colorRepValue = sprintf("%.2f", $max - $i * $numInc);
      $colorRepValue .= "+" if $maxGreaterThanThreshold and $i == 0;
      $self->_draw_text($legend, ($coordinates[0] + $coordinates[2])/2, $coordinates[3] + 3,
                                             		       'gdSmallFont', $colorRepValue); 
   }
   $self->_combine_image_and_legend($legend);
}

#Draws a rectangle at the position given in given image
sub _draw_rectangle
{
   my ($self, $image, $start_x, $start_y, $end_x, $end_y,
			 $redValue, $blueValue, $greenValue) = @_;
   my $color = $image->colorAllocate($redValue, $blueValue, $greenValue);
   $image->filledRectangle($start_x, $start_y, $end_x, $end_y, 
}

#Draws text at position given in given image
sub _draw_text
{
   my ($self, $image, $start_x, $start_y, $font, $text) = @_;
   my $textColor = $image->colorAllocate(0,0,0);
   $image->string($font, $start_x, $start_y, $text, $textColor); 
}

sub _combine_image_and_legend
{
   my ($self, $legend) =  @_;
   $self->image = $self->_build_image();
   my $new_image = new GD::Image($legend->width + $self->image->width, 
				    $legend->height + $self->image->height);
   #Copies the legend onto the upper right hand corner of the new image
   $new_image->copy($legend,0,0,0,0,$legend->width, $legend->height);
   #Copies the original image onto the new image next to the legend
   $new_image->copy($self->image,$legend->width,0,0,0,
				$self->image->width, $self->image->height);
   $self->image = $new_image;
}

__PACKAGE__->meta->make_immutable;
1;

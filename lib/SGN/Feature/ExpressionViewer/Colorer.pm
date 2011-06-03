package SGN::Feature::ExpressionViewer::Colorer;
use Moose;
use GD::Image;
use Moose::Util::TypeConstraints;

subtype 'Image',
   as 'GD::Image',
   where {!($_->isTrueColor);},
   message {"Image is true color! Need palette image."};

has 'image_source' => (isa => "Str", is => "ro", required => 1,);
has 'image' => (isa => "Image", is => "rw", lazy_build => 1,);

sub _build_image
{
   #GD::Image->trueColor(1);
   my $image = GD::Image->new(shift->image_source);
   #$image;
   #$self->image(GD::Image->new($image->width(), $image->height(), 1));

   #$self->image->trueColor(1);
   #$self->image->copy($image, 0, 0, 0, 0, $image->width, $image->height);
   #$self->image;
}

sub reset_image
{
   my $self = shift;
   $self->image($self->_build_image);
}

#Converts an index of the given current RGB values to a new index
#of the given new RGB values
#Takes no action if index is not found or RGB values specify black or white. 
sub changeColorIndex
{
   my ($self, $red, $green, $blue, $new_red, $new_green, $new_blue) = @_;
   my $color_index = $self->image->colorExact($red, $green, $blue);
   #print "Hello\t$red, $green, $blue, $new_red, $new_green, $new_blue\t$color_index\t";#$self->image->colorsTotal;
   #foreach my $index (0..255) {print "RGB: ".join(", ", $self->image->rgb($index)) . "\n"};
   #If color_index is found and neither RGB values reference black or white
   if ($color_index != -1 and 
	$self->_index_is_valid($red, $green, $blue, $new_red, $new_green, $new_blue))
   {
      GD::Image->trueColor(0);
      $self->image->colorDeallocate($color_index);
      my $index = $self->image->colorAllocate($new_red, $new_green, $new_blue);
      #print "World!\t$index\t" . join(",", $self->image->rgb($index)) . "\n";
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
#sub draw_absolute_legend
#{
   #my ($self, $min, $max, $min_colors, $max_colors, $threshold) = @_;
   #my $legend = new GD::Image(140, 50);
   #Sets the background of legend to white
   #$legend->colorAllocate(255,255,255);
   #$self->_draw_text($legend, 10, 10, GD::Font::gdMediumBoldFont, 'Absolute');
   #Assumes for absolute data we changed the green intensity of RGB
   #my $colorInc = ($$max_colors[1] - $$min_colors[1])/9;
   #my $numInc = ($max - $min)/9;
   #for my $i (0..9)
   #{
      #my @coordinates = (20 + $i * 10, 10, 30 + $i * 10, 25);
      #$self->_draw_rectangle($legend, @coordinates,  
			#255, floor($$max_colors[1] - $i * $colorInc + .5), 0); 
      #my $colorRepValue = sprintf("%.2f", $max - $i * $numInc);
      #$colorRepValue .= "+" if $max > $threshold and $i == 0;
      #Puts the text in the vertical middle of the block 
      #and 3 away horizontally to the right
      #$self->_draw_text($legend, ($coordinates[0] + $coordinates[2])/2, 
		#$coordinates[3] + 3, GD::Font::gdSmallFont, $colorRepValue); 
   #}
   #$self->_combine_image_and_legend($legend);
#}

#Draws the legend for a relative expression picture
#sub draw_relative_legend
#{
   #my ($self, $min, $max, $min_colors, $max_colors, $threshold) = @_;
   #my $legend = new GD::Image(140, 50);
   #Sets the background of legend to white
   #$legend->colorAllocate(255,255,255);
   #$self->_draw_text($legend, 10, 10, GD::Font::gdMediumBoldFont, 'Ratio log2');
   #Assumes those above median have green modified and those below have
   #yellow modified from zero
   #my $colorInc = (255 - $$max_colors[1] + 255 - $$min_colors[2])/9;
   #my $numInc = ($max - $min)/9;
   #for my $i (0..9)
   #{
      #my $greenChange = floor($$max_colors[1] + $i * $colorInc + .5);
      #my @coordinates = (20 + $i * 10, 10, 30 + $i * 10, 25);
      #if ($greenChange < 255)
      #{
         #$self->_draw_rectangle($legend, @coordinates, 255, $greenChange, 0); 
      #}
      #else
      #{
         #my $colorShift = $greenChange % 255;
         #$self->_draw_rectangle($legend, @coordinates, 
				    #255 - $colorShift, 255 - $colorShift, $colorShift); 
      #}
      #my $colorRepValue = sprintf("%.2f", $max - $i * $numInc);
      #$colorRepValue .= "+" if ($max > $threshold and $i == 0);
      #$self->_draw_text($legend, ($coordinates[0] + $coordinates[2])/2, $coordinates[3] + 3, GD::Font::gdSmallFont, $colorRepValue); 
   #}
   #$self->_combine_image_and_legend($legend);
#}

#Draws a rectangle at the position given in given image
#sub _draw_rectangle
#{
   #my ($self, $image, $start_x, $start_y, $end_x, $end_y,
			 #$redValue, $blueValue, $greenValue) = @_;
   #my $color = $image->colorAllocate($redValue, $blueValue, $greenValue);
   #$image->filledRectangle($start_x, $start_y, $end_x, $end_y, $color); 
#}

#Draws text at position given in given image
#sub _draw_text
#{
   #my ($self, $image, $start_x, $start_y, $font, $text) = @_;
   #my $textColor = $image->colorAllocate(0,0,0);
   #$image->string($font, $start_x, $start_y, $text, $textColor); 
#}

#sub _combine_image_and_legend
#{
   #my ($self, $legend) =  @_;
   #my $new_image = new GD::Image($legend->width + $self->image->width, 
				    #$legend->height + $self->image->height);
   #Copies the legend onto the upper right hand corner of the new image
   #$new_image->copy($legend,0,0,0,0,$legend->width, $legend->height);
   #Copies the original image onto the new image next to the legend
   #$new_image->copy($self->image,$legend->width,0,0,0,
				#$self->image->width, $self->image->height);
   #$self->image = $new_image;
#}

__PACKAGE__->meta->make_immutable;
1;

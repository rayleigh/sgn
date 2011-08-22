package SGN::Feature::ExpressionViewer::Colorer;
use Moose;
use GD::Image;

has 'image_source' => (isa => "Str", is => "ro", required => 1);
has 'image' => (isa => "GD::Image", is => "rw", lazy_build => 1);

sub _build_image
{
   GD::Image->trueColor(1);
   GD::Image->new(shift->image_source);
}

sub reset_image
{
   my $self = shift;
   $self->image($self->_build_image);
}

sub change_color
{
   my ($self, $coord_ref, $red, $green, $blue, 
			$new_red, $new_green, $new_blue) = @_;
   for my $coord (@$coord_ref)
   {
      my ($x, $y) = split(/,/, $coord);
      #print "$cur_color\t" . $self->image->getPixel($x,$y) . "\t" . $self->image->colorExact($red, $green, $blue) . "\t" . $self->image->colorResolve($red, $green, $blue) . "\n";
      if ($self->_pixel_selected_is_valid($x, $y, $red, $green, $blue))
      {
         my $new_color = 
	      $self->image->colorAllocate($new_red, $new_green, $new_blue);
         $self->image->fill($x, $y, $new_color);
      }
   }
}

#RGB values are valid if they do not specify white
sub _pixel_selected_is_valid
{
   my ($self, $x, $y, $red, $green, $blue) = @_;
   my @color = $self->image->rgb($self->image->getPixel($x,$y));
   return $red == $color[0] and $green == $color[1] and $blue == $color[2];
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

__PACKAGE__->meta->make_immutable;
1;

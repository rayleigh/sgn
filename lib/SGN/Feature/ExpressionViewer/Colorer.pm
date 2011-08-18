package SGN::Feature::ExpressionViewer::Colorer;
use Moose;
use GD::Image;
use Moose::Util::TypeConstraints;

subtype 'Image',
   => as 'GD::Image',
   => where {!($_->isTrueColor)},
   => message{"True color image! Need palette or indexed color!"};

has 'image_source' => (isa => "Str", is => "ro", required => 1,);
has 'image' => (isa => "Image", is => "rw", lazy_build => 1,);

sub _build_image
{
   GD::Image->new(shift->image_source);
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

__PACKAGE__->meta->make_immutable;
1;

package SGN::ExpressionViewer::Colorer;
use Moose;
use GD::Image;
use POSIX;

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
      if ($self->_pixel_selected_has_right_color($x, $y, $red, $green, $blue))
      {
	 #print STDERR "$red, $green, $blue, $new_red, $new_green, $new_blue\n";
         my $new_color = 
	      $self->image->colorAllocate($new_red, $new_green, $new_blue);
         #print STDERR "$new_color\n";
         $self->image->fill($x, $y, $new_color);
      }
   }
}

#Creates an image combining list of images
#Note: make sure all images are independent of each other so if 
#using the same image, use self->reset_image before modifying it again
sub createMosiac
{
   my ($self, $img_list_ref) = @_;
   my ($width, $height) = $self->image->getBounds;
   my @img_list = @$img_list_ref;
   my $num_img = scalar @img_list;
   my ($num_cols, $num_rows) = $self->_get_closest_square_factors($num_img, 
								  $num_img);
   $num_rows = ($num_rows * $num_cols == $num_img ) ?
                  $num_rows : ceil($num_img / $num_cols);

   my $mosiac = GD::Image->new($num_cols * $width, $num_rows * $height, 1);
   my $i = 0;
   for my $img (@img_list)
   {
      my ($img_x_loc, $img_y_loc) = (($i % $num_cols) * $width, 
					floor($i/$num_cols) * $height);
      $mosiac->copy($img, $img_x_loc, $img_y_loc, 0, 0, $width, $height);
      $i++;
   }
   return $mosiac;
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

#Tests whether pixel selected has the right RGB values
sub _pixel_selected_has_right_color
{
   my ($self, $x, $y, $red, $green, $blue) = @_;
   my @color = $self->image->rgb($self->image->getPixel($x,$y));
   return $red == $color[0] and $green == $color[1] and $blue == $color[2];
}

sub _get_closest_square_factors
{
   my ($self, $num, $original_num) = @_;
   my $x = ceil(sqrt($num));
   my $y = $num/$x;
   while (floor($y) != ceil($y))
   {
      $x++;
      $y = $num/$x;
   }
   return ($x, $y) if $x - $y < 5;
   return $self->get_closet_square_factors($self, ($num - 1), $original_num);
}

__PACKAGE__->meta->make_immutable;
1;

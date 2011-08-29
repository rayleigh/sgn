#!/usr/bin/perl

use strict;
use warnings;
use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Feature::ExpressionViewer::Colorer;
use GD::Image;
use File::Temp qw/ :seekable /;

$File::Temp::KEEP_ALL = 1;

#Creates three rectangles (one black, one white, and one with RGB values
#given in @test_color) and then stores it in a temp file
#Assigns pixel coordinates according to color
#(Can get away with this because colors are unique)
my @test_color = (126, 71, 8);
my @new_test_color = (26, 166, 9);
my $image = new GD::Image(180, 200);
my $white = $image->colorAllocate(255,255,255);
my $black = $image->colorAllocate(0,0,0);
my $color = $image->colorAllocate(@test_color);
my $new_color = $image->colorAllocate(@new_test_color);
my %color_to_pixel = ();
$image->filledRectangle(10, 10, 50, 190, $white);
$color_to_pixel{"255,255,255"} = ["35,100"];
$image->filledRectangle(60, 10, 110, 190, $black);
$color_to_pixel{"0,0,0"} = ["85,100"];
$image->filledRectangle(120, 10, 170, 190, $color);
$color_to_pixel{join(",",@test_color)} = ["135, 100"];
my $pngdata = $image->png();
my $fh = File::Temp->new(SUFFIX=>'.png');
my $testoutfile = $fh->filename;
diag("Original file name: ".$testoutfile);
binmode $fh;
print $fh $pngdata;
close $fh;

#Tests the Colorer with the file of the three rectangles created before
my $highlighter = SGN::Feature::ExpressionViewer::Colorer->new('image_source' => $testoutfile);
can_ok($highlighter, qw(change_color writeImageAsPNGFile pixel_selected_has_right_color reset_image _build_image));

diag("Trying to change non-existing color");
$highlighter->change_color($color_to_pixel{join(",",@test_color)},0,2,5,@test_color);
noChangesOccur();
my $fHandle = File::Temp->new(SUFFIX=>'.png');
$highlighter->writeImageAsPNGFile();
$highlighter->writeImageAsPNGFile($fHandle->filename);
diag("Should have no change file: ".$fHandle->filename);

diag("Trying to change color to black");
$highlighter->change_color($color_to_pixel{join(",",@test_color)},@test_color,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$highlighter->writeImageAsPNGFile();
$highlighter->writeImageAsPNGFile($fHandle->filename);
diag("Changed to black file: ".$fHandle->filename);

#noChangesOccur();
#$highlighter->change_color(@test_color,255,255,255); 
#noChangesOccur();

diag("Reseting image");
$highlighter->reset_image;

diag("Trying to change from to new color");
$highlighter->change_color($color_to_pixel{join(",",@test_color)},@test_color, @new_test_color);
cmp_ok($highlighter->image->colorExact(@new_test_color), '!=', -1, "New color did not result.");

diag("Trying to save changes.");
$fHandle = File::Temp->new(SUFFIX=>'.png');
$highlighter->writeImageAsPNGFile();
$highlighter->writeImageAsPNGFile($fHandle->filename);
diag("Changed to new color file: ".$fHandle->filename);
close $fHandle;

#Checks to see if no rectangles' colors are changed
sub noChangesOccur
{
   diag("Checking that no changes occured");
   cmp_ok($highlighter->image->colorExact(0,0,0), '!=',
			 -1, "Black shouldn't be changed");
   cmp_ok($highlighter->image->colorExact(255,255,255), '!=',
			 -1, "White shouldn't be changed");
   cmp_ok($highlighter->image->colorExact(@test_color), '!=', 
			 -1, "Current color shouldn't change");
}

done_testing;

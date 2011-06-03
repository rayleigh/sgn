#!/usr/bin/perl

use strict;
use warnings;
use Test::More qw | no_plan |;
use lib 't/lib';
BEGIN {
   use_ok('SGN::Feature::ExpressionViewer::Colorer');
   use_ok('GD::Image');
   use_ok('File::Temp', qw/ :seekable /);
}

$File::Temp::KEEP_ALL = 1;

#Creates three rectangles (one black, one white, and one with RGB values
#given in @test_color) and then stores it in a temp file
my @test_color = (126, 71, 8);
my @new_test_color = (26, 166, 9);
my $image = new GD::Image(180, 200);
my $white = $image->colorAllocate(255,255,255);
my $black = $image->colorAllocate(0,0,0);
my $color = $image->colorAllocate(@test_color);
my $new_color = $image->colorAllocate(@new_test_color);
$image->filledRectangle(10, 10, 50, 190, $white);
$image->filledRectangle(60, 10, 110, 190, $black);
$image->filledRectangle(120, 10, 170, 190, $color);
my $pngdata = $image->png();
my $fh = File::Temp->new(SUFFIX=>'.png');
my $testoutfile = $fh->filename;
diag("Original file name: ".$testoutfile);
binmode $fh;
print $fh $pngdata;
close $fh;

#Tests the Colorer with the file of the three rectangles created before
my $highlighter = SGN::Feature::ExpressionViewer::Colorer->new('image_source' => $testoutfile);
diag('Tests if Colorer was created');
isa_ok($highlighter, 'SGN::Feature::ExpressionViewer::Colorer');
diag('Tests if Colorer can do its methods');
can_ok($highlighter, qw(changeColorIndex writeImageAsPNGFile reset_image)); 
#draw_absolute_legend draw_relative_legend _draw_rectangle _draw_text _combine_image_and_legend));

diag("Trying to change white and black");
$highlighter->changeColorIndex(0,0,0,@test_color);
$highlighter->changeColorIndex(255,255,255,@test_color);
noChangesOccur();

diag("Trying to change non-existing color");
$highlighter->changeColorIndex(0,2,5,@test_color);
noChangesOccur();

diag("Trying to change color to black and white");
$highlighter->changeColorIndex(@test_color,0,0,0);
noChangesOccur();
$highlighter->changeColorIndex(@test_color,255,255,255); 
noChangesOccur();

diag("Trying to change color to new color");
$highlighter->changeColorIndex(@test_color,@new_test_color);
cmp_ok($highlighter->image->colorExact(@new_test_color), '!=', -1, "New color did not result.");
cmp_ok($highlighter->image->colorExact(@test_color), '==', -1, "Old color is still there.");

diag("Trying to save changes.");
my $fHandle = File::Temp->new(SUFFIX=>'.png');
$highlighter->writeImageAsPNGFile();
$highlighter->writeImageAsPNGFile($fHandle->filename);
diag("Changed file name: ".$fHandle->filename);
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

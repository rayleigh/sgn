#!usr/bin/perl

use strict;
use warnings;
use SGN::Feature::ExpressionViewer::Analyzer;
use File::Temp;

$File::Temp::KEEP_ALL = 1;

open DATA, "<", 'exp_data.txt';
my %data;
my %PO_term_to_coord;
my %PO_term_to_color;
while(<DATA>)
{
   chomp;
   my @entries = split /\t/;
   my $term = $entries[0];
   $data{$term} = "$entries[1],$entries[2]";
   $PO_term_to_color{$term} = $entries[3];
   my @coord = split(/#/, $entries[4]);
   $PO_term_to_coord{$term} = \@coord;
}
close DATA;
my @order = keys %data;
my %children;

my $test_analyzer = SGN::Feature::ExpressionViewer::Analyzer->new(
			'image_source'=> 'S.lycopersicum_cv.m82_image.png',
			'data' => \%data,
			'PO_term_to_color' => \%PO_term_to_color,
			'PO_term_order' => \@order,
			'PO_terms_childs' => \%children,
			'PO_term_pixel_location' => \%PO_term_to_coord);
$test_analyzer->make_absolute_picture(-9**9**9,0,0,0);
my $fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
print $fHandle->filename . "\n";
close $fHandle;

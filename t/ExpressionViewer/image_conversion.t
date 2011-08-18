#!usr/bin/perl

#Explicitly tests the SGN::Feature::ExpressionViewer::Analyzer 
#and SGN::Feature::Expression::Converter 
#The resulting image should have the maxed color correctly, but not the min
#because of cutoff.

use strict;
use warnings;
use Test::More qw | no_plan |;
use lib 't/lib/';
#diag('Sees if it can use the modules');
BEGIN {
   use_ok('SGN::Feature::ExpressionViewer::Colorer');
   use_ok('SGN::Feature::ExpressionViewer::Converter');
   use_ok('SGN::Feature::ExpressionViewer::Analyzer');
   use_ok('File::Temp', qw/ :seekable /);
}
$File::Temp::KEEP_ALL = 1;

my %important_info = ();

#Generates random data

#Creates a list of random PO_terms and stores it in a file
my $PO_term_fHandle = File::Temp->new(SUFFIX=>'.txt');
my $storage_file_name = $PO_term_fHandle->filename;
$important_info{'storage_file'} = $storage_file_name; 
my @PO_terms = ();
for my $i (0..20)
{
    push @PO_terms, "PO0000" . sprintf("%04d", int(rand(10000)));
}
print $PO_term_fHandle @PO_terms;

#Creates data for the PO terms so that the first PO_term has
#exp value of the number of PO terms and the control is 1
#and then decreases the exp value and increases the control value 
my %data = map{$_ => ''} @PO_terms;
my @unique_PO_terms = keys %data;
my $rand_size = scalar @unique_PO_terms - 3; #Number of PO terms to be used
my $rand_index = 
      int(rand($rand_size)); #Random index to decide which term is repeated 
my ($i, $j) = (scalar @unique_PO_terms,1);
for my $term (@unique_PO_terms)
{
   my $exp_value = $i;
   my $control_value = $j;
   $data{$term} = "$exp_value,$control_value";
   print $PO_term_fHandle "$term\t$exp_value\t$control_value\n";
   $i--;
   $j++;
}

#Assigns color to a certain number of PO_terms
my @unused_data_PO_terms = ();
my %PO_term_to_color = map{$_ => 0} @unique_PO_terms; 
for my $i (0..scalar @unique_PO_terms - 1)
{
   my $term = $unique_PO_terms[$i];
   if ($i < $rand_size || $i == $rand_index)
   {
      my $color = "0,0," . (255 - $i * 10);
      $PO_term_to_color{$term} = "$color";
      print $PO_term_fHandle "$term\t$color\n";
   }
   else
   {
      push @unused_data_PO_terms, $term;
      delete $PO_term_to_color{$term};
   }
}

#Creates supplemental PO terms so all colors are taken
my @supplemental_PO_terms = ();
while (scalar keys %PO_term_to_color < 25)
{
    my ($term, $color) = ("PO0000" . sprintf("%04d", int(rand(10000))), 
		    "0,0," . (255 - scalar(keys(%PO_term_to_color)) * 10));
    unless ($PO_term_to_color{$term})
    {
        push @supplemental_PO_terms, $term;
        $PO_term_to_color{$term} = "$color";
        print $PO_term_fHandle "$term\t$color\n";
    }
}

#Selects a term to be repeated
my $repeated_PO_term = $unique_PO_terms[$rand_index]; 
push @unique_PO_terms, $repeated_PO_term;
$important_info{'repeated_PO'} = $repeated_PO_term;

#Selects two terms to have children terms
#One PO_term is before the repeated term  and the other is after
my %child_PO_term = map {$_ => []} keys %data; 
my @picture_PO_terms = keys %PO_term_to_color;
until ($i > $rand_index && $i < $rand_size)
{
   $i = int(rand(scalar keys %data)); 
} 
until ($j < $rand_index)
{
   $j = int(rand(scalar keys %data));
}
my ($other_term_i, $other_term_j) = ($unique_PO_terms[$i], 
					$unique_PO_terms[$j]);

#Assigns children terms
#Repeated term has all supplemental
#Other terms have randomly assigned supplemental terms
my @test_with_child = ($other_term_i, $other_term_j, $repeated_PO_term);
for my $term (@test_with_child)
{
    my $num_child = 1;
    if ($term eq $repeated_PO_term)
    {
       $num_child = scalar @supplemental_PO_terms;
    }
    else
    {
       $num_child = int(rand(scalar @supplemental_PO_terms - 1)) + 1;
    }
    my @child = ();
    while (scalar @child < $num_child)
    {
       my $i = int(rand(scalar @supplemental_PO_terms));
       push @child, splice(@supplemental_PO_terms, $i, 1);
       
    }
    my %temp = map{$_ => 1} @child;
    my @unique_child = keys %temp;
    $child_PO_term{$term} = \@unique_child;
    print $PO_term_fHandle "$term\t@unique_child\n";
    for my $child (@unique_child)
    {
       diag("$term\t$PO_term_to_color{$term}\t" . $PO_term_to_color{$child});
    }
}
$child_PO_term{$other_term_j} = [@{$child_PO_term{$other_term_j}},
			          $repeated_PO_term, 
				     @{$child_PO_term{$repeated_PO_term}}];
#Creates an extra term
$PO_term_to_color{'bob'} = '0,0,5';
diag("bob is an extraneous PO term to test it");

close $PO_term_fHandle;

my $test_analyzer = 
   SGN::Feature::ExpressionViewer::Analyzer->new(
				 'image_source'=>'test_img.png',
				 'data'=> \%data,
                                 'PO_term_to_color'=> \%PO_term_to_color,
				 'PO_term_order' => \@unique_PO_terms,
                                 'PO_terms_childs' => \%child_PO_term);
diag('Tests whether Analyzer was created');
isa_ok($test_analyzer, 'SGN::Feature::ExpressionViewer::Analyzer');

diag('Tests whether Converter was created');
isa_ok($test_analyzer->converter, 'SGN::Feature::ExpressionViewer::Converter');

diag('Tests whether Converter can do its methods');
can_ok($test_analyzer->converter, qw(calculate_absolute calculate_relative calculate_comparison get_min_and_max _load_data_into_stats_obj _threshold_is_valid _determine_max _get_ratio_between_control_and_mean));

diag('Tests whether Comparison Converter was created');
isa_ok($test_analyzer->compare_converter, 'SGN::Feature::ExpressionViewer::Converter');

diag('Tests whether Comparison Converter can do its methods');
can_ok($test_analyzer->compare_converter, qw(calculate_absolute calculate_relative calculate_comparison get_min_and_max _load_data_into_stats_obj _threshold_is_valid _determine_max _get_ratio_between_control_and_mean));

diag('Tests if Colorer was created');
isa_ok($test_analyzer->colorer, 'SGN::Feature::ExpressionViewer::Colorer');
isa_ok($test_analyzer->colorer->image, 'GD::Image');

diag('Tests whether Analyzer can do its methods');
can_ok($test_analyzer, qw(make_absolute_picture make_relative_picture make_comparison_picture _change_image _get_absolute_legend_outline _get_relative_legend_outline));

my $num_terms = scalar(keys(%data));

#Tests for no settings on 
$test_analyzer->make_absolute_picture(0,0,0,0);
my $fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (0,0,0,0)'} = $fHandle->filename;
close $fHandle; 
my %temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests for various thresholds settings
#Tests that if threshold > max, will not be used
$test_analyzer->make_absolute_picture(100,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (100,0,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests that if threshold < max, but is reasonable, will be used
$test_analyzer->make_absolute_picture(10,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (10,0,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');
$test_analyzer->make_absolute_picture(10,1,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (10,1,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests that if threshold is greater than max, it can be overwritten 
$test_analyzer->make_absolute_picture($num_terms + 5,1,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (' . ($num_terms + 5)  . ',1,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests that if threshold is less than min, it can be overwritten 
$test_analyzer->make_absolute_picture(-1,1,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (-1,1,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests grey mask
#Tests what happens if mask is off
$test_analyzer->make_absolute_picture(0,0,.5,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (0,0,.5,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests what happens if mask is on
$test_analyzer->make_absolute_picture(0,0,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (0,0,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests mask specified, but off, threshold and override on
$test_analyzer->make_absolute_picture($num_terms + 5,1,.5,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (' . ($num_terms + 5) . ',1,.5,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests mask specified and on, threshold specified and override off
$test_analyzer->make_absolute_picture($num_terms + 5,0,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (' . ($num_terms + 5) . ',0,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');
diag("PO term information are stored in " . $storage_file_name);

#Tests mask specified and on, threshold specified and override on
$test_analyzer->make_absolute_picture($num_terms + 5,1,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Ab image (' . ($num_terms + 5)  . ',1,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests relative
$test_analyzer->make_relative_picture(0,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (0,0,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests for various thresholds settings
#Tests that if threshold > max
$test_analyzer->make_relative_picture(100,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (100,0,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests that if threshold is less than max, it can be overwritten 
$test_analyzer->make_relative_picture($test_analyzer->converter->get_median - 1,1,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (' . ($test_analyzer->converter->get_median - 1) . ',1,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests grey mask
#Tests what happens if mask is off
$test_analyzer->make_relative_picture(0,0,.5,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (0,0,.5,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests what happens if mask is on
$test_analyzer->make_relative_picture(0,0,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (0,0,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests mask specified, but off, threshold and override on
$test_analyzer->make_relative_picture(10,1,.5,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (10,1,.5,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests mask specified and on, threshold specified and override off
$test_analyzer->make_relative_picture(10,0,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (10,0,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');
diag("PO term information are stored in " . $storage_file_name);

#Tests mask specified and on, threshold specified and override on
$test_analyzer->make_relative_picture(10,1,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Rel image (10,1,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests comparison

#Creates comparison data by flipping experimental and control values
my %comparison = ();
for my $PO_term (keys %data)
{
   my $entry = $data{$PO_term};
   $entry =~ s/(.*?),(.*)/$2,$1/;   
   $comparison{$PO_term} = $entry;
}

#Sets the comparison
$test_analyzer->compare_data(\%comparison);

for my $term ($test_analyzer->compare_converter->tissues)
{
    diag($term);
    #diag($test_analyzer->compare_converter->gene_signal_in_tissue->{$term});
}

#Tests to make sure everything's okay
diag('Tests whether compare_converter was created');
isa_ok($test_analyzer->compare_converter, "SGN::Feature::ExpressionViewer::Converter");

diag('Tests whether compare_converter can do its methods');
can_ok($test_analyzer->compare_converter, qw(calculate_absolute calculate_relative calculate_comparison get_min_and_max _load_data_into_stats_obj _threshold_is_valid _determine_max _get_ratio_between_control_and_mean));

$test_analyzer->make_comparison_picture(0,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (0,0,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests for various thresholds settings
#Tests that if threshold > max
$test_analyzer->make_comparison_picture(100,0,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (100,0,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests that if threshold is less than max, it can be overwritten 
$test_analyzer->make_comparison_picture(10,1,0,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (10,1,0,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests grey mask
#Tests what happens if mask is off
$test_analyzer->make_comparison_picture(0,0,.5,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (0,0,.5,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests what happens if mask is on
$test_analyzer->make_comparison_picture(0,0,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (0,0,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests mask specified, but off, threshold and override on
$test_analyzer->make_comparison_picture(10,1,.5,0);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (10,1,.5,0)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

#Tests mask specified and on, threshold specified and override off
$test_analyzer->make_comparison_picture(10,0,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (10,0,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');
diag("PO term information are stored in " . $storage_file_name);

#Tests mask specified and on, threshold specified and override on
$test_analyzer->make_comparison_picture(10,1,.5,1);
$fHandle = File::Temp->new(SUFFIX=>'.png');
$test_analyzer->colorer->writeImageAsPNGFile($fHandle->filename);
$important_info{'Comparison image (10,1,.5,1)'} = $fHandle->filename;
close $fHandle; 
%temp = map{$_ => 1} (@unused_data_PO_terms, 
			    @{$test_analyzer->PO_terms_not_shown});
cmp_ok(scalar @unused_data_PO_terms, '==', scalar(keys(%temp)), 
	   'Checking if Data PO terms correctly included into picture');

for my $desc (sort keys %important_info)
{
   diag ("${desc}: $important_info{$desc}");
}
diag("$PO_term_to_color{$other_term_j}\t$PO_term_to_color{$repeated_PO_term}\t$PO_term_to_color{$other_term_i}");
diag("The median is " . $test_analyzer->converter->get_median);
#The formula used to calculate intensity is (255, floor(255.5 - $max), 0)
#Test should test if no parameters are entered, where max = max of the data; 
#then an 'invalid', (above the max or below the 5th percentile), with 
#override off, max = max of data, invalid, with override on, max = threshold, 
#and valid threshold, max=threshold, should be tested; then grey mask should be #tested, with and without the threshold as above.
#Repeat it for the two other calculate, i.e. calculate_relative and
#calculate_comparison
#my $testingAnalyzer = 
#	SGN::Feature::ExpressionViewer:ExpressionDataAnalysis->new(
#		 -'gene_signal_in_tissue' => %testSignalFromTissue,
#	            -'control_signal_for_tissue' => %controlSignalFromTissue);
#$testingAnalyzer->calculate_absolute();
#cmp_ok(

done_testing;

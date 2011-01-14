#!usr/bin/perl

use strict;
use warnings;
use SGN::Feature::ExpressionViewer::ExpressionDataAnalysis;
use Test::More qw | no_plan |;
use lib 't/lib/';

#Takes a tab delimited file with tissue, signal strength, and control signal
#strength
#First way takes as command line input, second assumes a file in current
#directory
#my $testSignalFileName = shift or die "Need testSignalFileName";
my $testSignalFileName = "testData.txt";

my %testSignalFromTissue;
my %controlSignalFromTissue;
open TESTINFO, "<", "$testSignalFileName";
while (<TESTINFO>)
{
   chomp;
   my @entries = split(/\t/); 
   $testSignalFromTissue{$entries[0]} = $entries[1];
   $controlSignalFromTissue{$entries[0]} = $entries[2];
}

#The formula used to calculate intensity is (255, floor(255.5 - $max), 0)
#Test should test if no parameters are entered, where max = max of the data; 
#then an 'invalid', (above the max or below the 5th percentile), with 
#override off, max = max of data, invalid, with override on, max = threshold, 
#and valid threshold, max=threshold, should be tested; then grey mask should be #tested, with and without the threshold as above.
#Repeat it for the two other calculate, i.e. calculate_relative and
#calculate_comparison
my $testingAnalyzer = 
	SGN::Feature::ExpressionViewer:ExpressionDataAnalysis->new(
		 -'gene_signal_in_tissue' => %testSignalFromTissue,
	            -'control_signal_for_tissue' => %controlSignalFromTissue);
$testingAnalyzer->calculate_absolute();
cmp_ok(

done_testing;

#!/usr/bin/perl -w

# Check sample sheet for any illegal characters

use warnings FATAL => "all";
use strict;
use Getopt::Long;
use Data::Dumper;
use File::Copy qw(copy);

my $ss = "";
my $help = 0;

Getopt::Long::GetOptions(
  'samplesheet=s' => \$ss,
  'help'      => \$help,
  ) or die "Incorrect input! Use -help for usage.\n";

if ($help) {
  print "\nUsage: ss_validate.pl -samplesheet <filename>\n";
  print "Options:\n";
  print "  -samplesheet    Samplesheet file, with full path\n";
  print "  -help           Display usage information.\n";
  exit 0;
}

($ss eq "") && die "Error: A samplesheet file must be provided. Use -help for usage.\n";
(! -e $ss) && die "Error: The samplesheet does not exist: $ss\n";

my $ss_orig = "$ss" . ".orig";
File::Copy::copy($ss, $ss_orig);

open(IN, "<$ss_orig") or die "Can't open file $ss_orig\n";
my $clean = <IN>; #read in header line
my $linenum = 2;
while (my $line = <IN>) {
  chomp($line);
  $line =~ s/( |\(|\)|\.|\/|\\|\t)+//g;  #remove disallowed characters
#  $line =~ s/ |\t//g;
#  $line =~ s/(\(|\)|\.|\/|\\)+/_/g;
  my @elems = split(',',$line);
  my $lane = $elems[1];
  my $index = $elems[4];
  my $recipe = $elems[7];

  if ($lane !~ m/^[12345678]$/) {
    die "Error: Invalid lane: \"$lane\" on line $linenum in $ss_orig\n";
  } elsif ($index !~ m/^[-ACGT]{3,}$/) {
    die "Error: Invalid index: \"$index\" on line $linenum in $ss_orig\n";
  } elsif ($recipe !~ m/^[0-9][0-9]*(_[0-9][0-9]*)?$/) {
    die "Error: Invalid recipe: \"$recipe\" on line $linenum in $ss_orig\n";
  }
  $clean = $clean . $line . "\n"; 
  $linenum++; 
}
close(IN);

#if none of the above errors were found, write out cleaned data
open(OUT, ">$ss") or die "Can't open file $ss\n";
print OUT $clean;
close(OUT);

exit 0;

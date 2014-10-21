#!/usr/bin/perl -w

# Check demux log files for errors, print demux summary, print user letter
# Example: ./val.pl 140521_D00365_0216_AH9N38ADXX

use warnings FATAL => "all";
use strict;
use Getopt::Long;
use File::Basename;
use autodie qw(open close);
use FindBin qw($Bin);
use lib "$Bin/../lib";
use HTML::TableExtract;
use Text::Table;
use constant { true => 1, false => 0 };

my $ngsdata = "/n/ngsdata";
my $analysis_finished = "/n/seqcfs/sequencing/analysis_finished";
my $logparent = (defined $ENV{'CASLOGROOT'}) ? $ENV{'CASLOGROOT'} : "/n/informatics/seq/casava_log"; #let environment variable override default location.
my $casava_commands = "begin|postprocess|fastqc|merge|md5sum";
my $print_letter = true;

my $run_out = $ARGV[0];
(!defined $run_out) && die "Error: A run output folder name must be provided.\n";

#Check that directories exist...
my $rundir = "";
if (-e "$ngsdata/$run_out") {
  $rundir = "$ngsdata/$run_out";
} elsif (-e "$analysis_finished/$run_out") {
  print "\n\nWARNING: Run folder $ngsdata/$run_out not found. Using $analysis_finished/$run_out\n\n";
  $rundir = "$analysis_finished/$run_out";
  $print_letter = false;
} else {
  die "Error: Run folder \"$run_out\" not found in $ngsdata or $analysis_finished.\n\n"
}

my $logdir = "$logparent/$run_out";
if (! -e $logdir) {
 print "\n\nWARNING: Log directory \"$logdir\" not found. Not scanning log files.\n\n";
} else {
  #Print any errors/warnings in log files.
  print "\n";
  scan_casava_outputfile($logdir, "out");
  scan_casava_outputfile($logdir, "err");
}

#Get casava dir names in run_out, and find all instances of Demultiplex_Stats.htm. Print run statistics
my @casdirs = `find $rundir -regextype posix-extended -maxdepth 1 -iregex \".*/BclToFastq_Lane.*\" -type d`;
die if $?;
@casdirs = sort @casdirs;
chomp(@casdirs);
print $#casdirs+1, " casava dirs:\n";
print "  ", join("\n  ", @casdirs), "\n\n";
foreach my $casdir (@casdirs) {
  print File::Basename::basename($casdir), " :\n\n";
  #Print summary of stats table in Demultiplex_Stats.htm
  my $statsfile = `find $casdir -regextype posix-extended -maxdepth 2 -regex \".*Basecall_Stats_.+/Demultiplex_Stats.htm\"`;
  die if $?;
  if ($statsfile eq "") { print "\nError: No Demultiplex_Stats.htm found in $casdir.\nContinuing to next lane...\n\n"; $print_letter = false; next }
  chomp($statsfile);
  my $html_string = fix_html($statsfile);
  my $te = HTML::TableExtract->new( headers => ["Sample ID", "# Reads", "Perc. bases with Q ge 30"] );
  $te->parse($html_string);
  my @tables = $te->tables;
  die "No tables found\n" unless @tables;
  my $tb = Text::Table->new("Sample", 
    { is_sep => 1, title  => "  |  ", body   => "  |   " },
    "Reads",
    { is_sep => 1, title  => "  |  ", body   => "  |   " },
    "Perc. bases with Q >= 30");
  $tb->load($tables[0]->rows);
  print "$tb\n\n";
}

#Print user letter
($print_letter) && print get_letter($run_out) . "\n";

exit 0;
  
sub fix_html {  #quick fix to merge header and table body into one html table, and replace a header name with a simpler one.
  my $file = shift;
  open(my $FH, "<", $file);
  my $html = do { local $/; <$FH> };
  $html =~ s{% of &gt;= Q30 Bases \(PF\)}{Perc. bases with Q ge 30}; 
  $html =~ s{</table></div>
<div ID="ScrollableTableBodyDiv"><table width="100%">
<col width="4%">
<col width="5%">
<col width="19%">
<col width="8%">
<col width="7%">
<col width="5%">
<col width="12%">
<col width="7%">
<col width="4%">
<col width="5%">
<col width="4%">
<col width="5%">
<col width="6%">
<col width="5%">
<col>
}{}g;
  return $html
}

sub scan_casava_outputfile {
  my $dir = shift;
  my $extension = shift;
  my $wholepath = `find $dir -regextype posix-extended -regex \".*($casava_commands).*\.$extension\" -not -name \"DBupdate.*\" -type f -exec stat --format '%Y %n' {} \\; | sort -nr | cut -d " " -f2 | head -n1`;
  chomp($wholepath);
  my $file = File::Basename::basename($wholepath);
  ($file eq "") && die "Error: No casava output file in \"$dir\" with extension \"$extension\" was found.\n";
  open(my $FH, "<", $wholepath);
  my @lines = <$FH>;
  close($FH);
  my @indices = grep {
    $lines[$_] =~ /error|exception|inconsistent| failed|failed |negative number of base/i
  } 0...$#lines;
  foreach my $index (@indices) {
    print "\n_____Error found in $wholepath at line $index:_____\n";
    print $lines[$index-2] if ($index-2>=0);
    print $lines[$index-1] if ($index-1>=0);
    print $lines[$index];
    print $lines[$index+1] if ($index+1<=$#lines);
    print $lines[$index+2] if ($index+2<=$#lines);

    print "\n\n"
  }
}

sub get_letter {
  my $run = shift;
  return "

Hi all,

The fastq files with the read sequences of run $run are available at:

https://software.rc.fas.harvard.edu/ngsdata/$run

or under /n/ngsdata/$run on the cluster.

In the appropriate Project folder look for the fastq files of your samples. Look at 
Demultiplex_Stats.htm in the Basecall_Stats folder for summary quality stats per 
library. Reads with indices not in the SampleSheet are in the Undetermined_indices 
folder.

We encourage users to download a local copy of their data, as run data will
eventually be removed from the ngsdata server.

Best,
Chris

"
}
__END__






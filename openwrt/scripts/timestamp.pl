#!/usr/bin/perl
use strict;

sub get_ts($$) {
	my $path = shift;
	my $options = shift;
	my $ts = 0;
	my $fn = "";
	open FIND, "find $path -not -path \\*.svn\\* -and -not -path \\*CVS\\* $options 2>/dev/null |";
	while (<FIND>) {
		chomp;
		my $file = $_;
		open FILE, "<$file";
		my @stat = stat FILE;
		close FILE;
		if ($stat[9] > $ts) {
			$ts = $stat[9];
			$fn = $file;
		}
	}
	close FIND;
	return ($ts, $fn);
}

(@ARGV > 0) or push @ARGV, ".";
my $ts = 0;
my $n = ".";
my %options;
while (@ARGV > 0) {
	my $path = shift @ARGV;
	if ($path =~ /^-x/) {
		my $str = shift @ARGV;
		$options{"-x"} .= " -and -not -path \\*".$str."\\*"
	} elsif ($path =~ /^-/) {
		$options{$path} = 1;
	} else {
		my ($tmp, $fname) = get_ts($path, $options{"-x"});
		if ($tmp > $ts) {
			if ($options{'-f'}) {
				$n = $fname;
			} else {
				$n = $path;
			}
			$ts = $tmp;
		}
	}
}

if ($options{"-p"}) {
	print "$n\n";
} elsif ($options{"-t"}) {
	print "$ts\n";
} else {
	print "$n\t$ts\n";
}

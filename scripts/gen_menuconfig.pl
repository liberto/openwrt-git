#!/usr/bin/perl
# 
# Copyright (C) 2006 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

use strict;

my $src;
my $makefile;
my $pkg;
my %package;
my %category;
my $cur_menu;
my $cur_menu_dep;

sub close_submenu {
	if ($cur_menu) {
		print "endmenu\n";
		$cur_menu_dep and do {
			print "endif\n";
			$cur_menu_dep = undef;
		};
		undef $cur_menu;
	} 
}

sub find_dep($$) {
	my $pkg = shift;
	my $name = shift;
	my $deps = ($pkg->{vdepends} or $pkg->{depends});

	return 0 unless defined $deps;
	foreach my $dep (@{$deps}) {
		return 1 if $dep eq $name;
		return 1 if ($package{$dep} and (find_dep($package{$dep},$name) == 1));
	}
	return 0;
}

sub depends($$) {
	my $a = shift;
	my $b = shift;
	my $ret;

	if (find_dep($a, $b->{name}) == 1) {
		$ret = 1;
	} elsif (find_dep($b, $a->{name}) == 1) {
		$ret = -1;
	} else {
		return 0;
	}
#	print STDERR "depends($a->{name}, $b->{name}) == $ret\n";
	return $ret;
}


sub print_category($) {
	my $cat = shift;
	
	return unless $category{$cat};
	
	print "menu \"$cat\"\n\n";
	my %spkg = %{$category{$cat}};
	foreach my $spkg (sort {uc($a) cmp uc($b)} keys %spkg) {
		my @pkgs = sort {
			depends($a, $b) or
			$a->{submenu}."->".$a->{name} cmp $b->{submenu}."->".$b->{name}
		} @{$spkg{$spkg}};
		foreach my $pkg (@pkgs) {
			if ($cur_menu ne $pkg->{submenu}) {
				close_submenu();
				if ($pkg->{submenu}) {
					$cur_menu = $pkg->{submenu};
					$cur_menu_dep = $pkg->{submenudep} and print "if $cur_menu_dep\n";
					print "menu \"$cur_menu\"\n";
				}
			}
			my $title = $pkg->{name};
			my $c = (72 - length($pkg->{name}) - length($pkg->{title}));
			if ($c > 0) {
				$title .= ("." x $c). " ". $pkg->{title};
			}
			print "\t";
			$pkg->{menu} and print "menu";
			print "config PACKAGE_".$pkg->{name}."\n";
			print "\t\ttristate \"$title\"\n";
			foreach my $default (split /\s*,\s*/, $pkg->{default}) {
				print "\t\tdefault $default\n";
			}
			foreach my $depend (@{$pkg->{depends}}) {
				my $m = "depends";
				$depend =~ s/^([@\+]+)//;
				my $flags = $1;
				my $vdep;
				
				if ($vdep = $package{$depend}->{vdepends}) {
					$depend = join("||", map { "PACKAGE_".$_ } @$vdep);
				} else {
					$flags =~ /@/ or $depend = "PACKAGE_$depend";
					$flags =~ /\+/ and $m = "select";
				}
				print "\t\t$m $depend\n";
			}
			print "\t\thelp\n";
			print $pkg->{description};
			print "\n";

			$pkg->{config} and print $pkg->{config}."\n";
		}
	}
	close_submenu();
	print "endmenu\n\n";
	
	undef $category{$cat};
}

my $line;
while ($line = <>) {
	chomp $line;
	$line =~ /^Source-Makefile: \s*(.+\/([^\/]+)\/Makefile)\s*$/ and do {
		$makefile = $1;
		$src = $2;
		undef $pkg;
	};
	$line =~ /^Package: \s*(.+)\s*$/ and do {
		$pkg = {};
		$pkg->{src} = $src;
		$pkg->{makefile} = $makefile;
		$pkg->{name} = $1;
		$pkg->{default} = "m if ALL";
		$package{$1} = $pkg;
	};
	$line =~ /^Version: \s*(.+)\s*$/ and $pkg->{version} = $1;
	$line =~ /^Title: \s*(.+)\s*$/ and $pkg->{title} = $1;
	$line =~ /^Menu: \s*(.+)\s*$/ and $pkg->{menu} = $1;
	$line =~ /^Submenu: \s*(.+)\s*$/ and $pkg->{submenu} = $1;
	$line =~ /^Submenu-Depends: \s*(.+)\s*$/ and $pkg->{submenudep} = $1;
	$line =~ /^Default: \s*(.+)\s*$/ and $pkg->{default} = $1;
	$line =~ /^Provides: \s*(.+)\s*$/ and do {
		my @vpkg = split /\s+/, $1;
		foreach my $vpkg (@vpkg) {
			$package{$vpkg} or $package{$vpkg} = { vdepends => [] };
			push @{$package{$vpkg}->{vdepends}}, $pkg->{name};
		}
	};
	$line =~ /^Depends: \s*(.+)\s*$/ and do {
		my @dep = split /\s+/, $1;
		$pkg->{depends} = \@dep;
	};
	$line =~ /^Category: \s*(.+)\s*$/ and do {
		$pkg->{category} = $1;
		defined $category{$1} or $category{$1} = {};
		defined $category{$1}->{$src} or $category{$1}->{$src} = [];
		push @{$category{$1}->{$src}}, $pkg;
	};
	$line =~ /^Description: \s*(.*)\s*$/ and do {
		my $desc = "\t\t$1\n\n";
		my $line;
		while ($line = <>) {
			last if $line =~ /^@@/;
			$desc .= "\t\t$line";
		}
		$pkg->{description} = $desc;
	};
	$line =~ /^Config: \s*(.*)\s*$/ and do {
		my $conf = "$1\n";
		my $line;
		while ($line = <>) {
			last if $line =~ /^@@/;
			$conf .= "$line";
		}
		$pkg->{config} = $conf;
	}
}

print_category 'Base system';
foreach my $cat (keys %category) {
	print_category $cat;
}

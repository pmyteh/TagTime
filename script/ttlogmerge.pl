#!/usr/bin/perl

# Syntax: ttlogmerge.pl logfile1 logfile2 [outputlogfile]
#
# A helper script for the Unison file synchroniser. One option for Unison is to
# use an external program to merge two files which have been change in both
# roots. This script uses this feature to merge two TagTime log files which
# have been created on different machines.
#
# In principle, this allows you to run TagTime on multiple computers and, as
# long as they have the same period and random seeds, create a merged file
# which tracks what you were doing on all your machines.
#
# If a ping only exists in one file, use it.
# If a ping exists in both files but one is tagged "RETRO", use the other.
# If a ping exists in both files and both or neither are tagged "RETRO",
#    then use the one with the most tags entered.
# Note that it is assumed that both files have timestamps in ascending order.
#
# This is best used by adding something like the following to your Unison
# preferences file:
#
# merge = Path path/to/tagtime/*.log -> /path/to/ttlogmerge.pl CURRENT1 CURRENT2 NEW

use strict;
use warnings;

sub longer
{
    my $a = shift;
    my $b = shift;
	length(&removeautotags($a)) >= length(&removeautotags($b)) ? $a : $b;
}

sub removeautotags
{
    my $s = shift;
    $s =~ s/\b(afk|off|RETRO|\[missed ping from \d+s ago\])\b//g;
    return $s;
}

sub parse
# Returns the initial timestamp and tag set
{
	my $s = $_[0];
	my @tokens = split(/\s+/, $s);
	# XXX FIXME: This may fail where huge numbers of tags are added:
	# It appears TT shortens the human-readable date string to stay
	# under 80 characters per line if possible.
    # Should probably use Text::Balanced to extract and discard
    # content from square brackets before tokenising:
    # http://perldoc.perl.org/Text/Balanced.html
	for my $i (1..3) { pop(@tokens) } # Discard date string
#	print STDERR "parse: ", $_[0], @tokens;
	return @tokens;
}

sub parse_timestamp
# Returns just the initial timestamp from a line
{
	my $s = $_[0];
	my @tokens = split(/\s+/, $s);
	print STDERR "parse_timestamp: ", $tokens[0];
	return $tokens[0];
}

open(my $f1, "<", shift) or die;
open(my $f2, "<", shift) or die;
my $outn = shift;
my $fo;
if ($outn) {
    open($fo, ">", $outn) or die;
} else {
    open($fo, '>&', \*STDOUT) or die;
}

# TODO: Should open the config file, and if we can, delete the .bee files
# associated with it. For extra credit, we should only remove the ones
# which are actually affected by the merge, possibly by flagging during
# the merge step which files are dirty and deleting them afterward.
#require "$ENV{HOME}/.tagtimerc";
#
#foreach my $usrslug (keys %beeminder) {
    # Extract the user/goal slugs from the .tagtimerc file, which lists all
    # the slugs with automatic beeminder submission
#    $usrslug =~ /^(?:.*?(?:\.\/)?data\/)?([^\+\/\.]*)[\+\/]([^\.]*)/;
#    (my $usr, my $slug) = ($1, $2);
#    # Erase the cache files if they're present
#    print "Erasing ${path}$usr+$slug.bee";
#    unlink "${path}$usr+$slug.bee";
#}

# Read initial lines from files
my $l1 = <$f1>;
my $l2 = <$f2>;

# If one file is present but empty, this will be skipped, and the other file
# will be copied into the output file by the second loop.
while (defined $l1 and defined $l2) {
	my @l1a = &parse($l1);
	my @l2a = &parse($l2);
	if (not defined $l1a[0] or not defined $l2a[0])
	{
		last; # Spurious blank line
	}
	if ($l1a[0] < $l2a[0]) {
		# f1 has ping not in f2
		print $fo $l1;
		$l1 = <$f1>;
	} elsif ($l1a[0] > $l2a[0]) {
		# f2 has ping not in f1
		print $fo $l2;
		$l2 = <$f2>;
	} else {
		# both f1 and f2 have a ping
		if ($l1 eq $l2) {
			# Identical. Print one copy and get new data
			print $fo $l1;
			$l1 = <$f1>;
			$l2 = <$f2>;
		} else {
			# Different content.
			if (index($l1, " RETRO ") != -1) {
				if (index($l2, " RETRO ") != -1) {
					# Both RETRO - print longer
					print $fo &longer($l1, $l2);
				} else {
					# 1 RETRO, 2 not
					print $fo $l2;
				} 
			} elsif (index($l2, "RETRO") != -1) {
				# 2 RETRO, 1 not
				print $fo $l1;
			} else {
				 # Both non-RETRO (shouldn't really happen)
				print $fo &longer($l1, $l2);
			}
			# Get new lines from both files
			$l1 = <$f1>;
			$l2 = <$f2>;
		}
	}
} 

# One or both of the files is exhausted and its line undefined.
# Any non-undefined files have unprocessed data in $lx
if (defined $l1) {
	do {
#		print STDERR "Extra line in f1. Writing.\n", $l1; 
		print $fo $l1
	} while ($l1 = <$f1>);
} elsif (defined $l2) {
	do {
#		print STDERR "Extra line in f2. Writing.\n", $l2; 
		print $fo $l2
	} while ($l2 = <$f2>);
}			

exit(0);

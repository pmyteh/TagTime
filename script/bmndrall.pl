#!/usr/bin/env perl
# Call beeminder.pl for all defined slugs in the user's .tagtimerc file.
# Used to ensure all graphs are up to date after network failure or log file
# merge.

require "$ENV{HOME}/.tagtimerc";

foreach my $slug (keys %beeminder) {
    system("${path}beeminder.pl", $logf, $slug);
}


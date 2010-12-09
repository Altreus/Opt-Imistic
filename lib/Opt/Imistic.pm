package Opt::Imistic;
use strict;
use warnings;

our %opts;

sub import {
    # we alter @ARGV on purpose.
    while (my $arg = shift @ARGV) {
        last if $arg eq '--';

        if (substr($arg, 0, 2) eq '--') {
            # Double dash (Mario Kart) - long opt!
            substr $arg, 0, 2, '';

            if (substr($ARGV[0], 0, 1) ne '-') {
                # if the next opt is not an opt, it is kv!
                my $val = shift @ARGV;
                $val = [ split /,/, $val ] if $val =~ /,/;
                $opts{$arg} = $val;
            }
            elsif (index($arg, '=') > -1) {
                ($arg, my $val) = split /=/, $arg;
                $val = [ split /,/, $val ] if $val =~ /,/;
                $opts{$arg} = $val;
            }
            else {
                $opts{$arg} = 1;
            }
        }
        elsif (substr($arg, 0, 1) eq '-') {
            # single-letter opts
            substr $arg, 0, 1, '';
            my @opts = split //, $arg;

            @opts{@opts} = (1) x @opts;
            if (substr($ARGV[0], 0, 1) ne '-') {
                $opts{$opts[-1]} = shift @ARGV;
            }
        }
        else {
            # Put it back if options have ended.
            unshift @ARGV, $arg;
            last;
        }
    }

    push @{ $opts{_} }, @ARGV;
}

1;

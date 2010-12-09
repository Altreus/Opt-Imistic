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

            my $val;

            if (index($arg, '=') > -1) {
                ($arg, $val) = split /=/, $arg;
                $val = [ split /,/, $val ] if $val =~ /,/;
            }
            else {
                $val = _can_has_value();
            }

            _store($arg, $val);
        }
        elsif (substr($arg, 0, 1) eq '-') {
            # single-letter opts
            substr $arg, 0, 1, '';
            my @opts = split //, $arg;

            # Goodbye, awesome code :(
            # @opts{@opts} = (1) x @opts;
            
            my $val = _can_has_value();
            _store(pop @opts, $val) if defined $val;

            _store($_) for @opts;
        }
        else {
            # Put it back if options have ended.
            unshift @ARGV, $arg;
            last;
        }
    }

    _store('-', $_) for @ARGV;
}

# Stores repeated options in an array.
sub _store {
    my ($arg, $val) = @_;


    if (exists $opts{$arg}) {
        if (defined $val) {
            $opts{$arg} = [ $opts{$arg} ] unless ref $opts{$arg};
            push @{ $opts{$arg} }, $val;
        }
        else {
            $opts{$arg}++;
        }
    } else {
        $opts{$arg} = $val // 1;
    }
}

# Checks to see whether the next @ARGV is a value and returns it if so.
# shifts @ARGV so we skip it in the outer while loop. This is naughty but
# shut up :(
sub _can_has_value {
    my $val = $ARGV[0];

    if ($val eq '-') {
        return shift @ARGV;
    }

    if (index($val, '-') == 0) {
        # starts with - but isn't - means option. (Includes --)
        return;
    }

    return shift @ARGV;
}
1;

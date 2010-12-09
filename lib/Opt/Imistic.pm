# ABSTRACT: Very quick and simple and unobtrusive option parser
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
            
            if (defined(my $val = _can_has_value())) {
                _store(pop @opts, $val);
            }

            _store($_) for @opts;
        }
        else {
            # Put it back if options have ended.
            unshift @ARGV, $arg;
            last;
        }
    }

    for my $o ( keys %opts ) {
        $opts{$o} = 1 and next if not defined $opts{$o};

        if (ref $opts{$o} eq 'ARRAY') {
            # provide a count for any option that never got a value.
            $opts{$o} = @{ $opts{$o} } unless grep defined, @{ $opts{$o} };
        }
    }

    _store('-', $_) for @ARGV;
}

# Stores repeated options in an array.
sub _store {
    my ($arg, $val) = @_;

    # tm604 suggested that, to accommodate an occurence such as:
    #   script --opt --opt --opt=foo --opt=123
    # we create opt => [ undef, undef, 'foo', '123' ].
    # Then we can collapse undef-only arrayrefs into counts later. So we don't
    # care if the val is undef. yay!

    if (exists $opts{$arg}) {
            $opts{$arg} = [ $opts{$arg} ] unless ref $opts{$arg} eq 'ARRAY';
            push @{ $opts{$arg} }, $val;
    } else {
        $opts{$arg} = $val;
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

__END__

=head1 NAME

Opt::Imistic - Optimistic option parsing

=head1 SYNOPSIS

    use Opt::Imistic;
    die if $Opt::Imistic::opts{exit};

=head1 

=head1 DESCRIPTION

Most option parsers end up doing the same thing but you have to write a whole
spec to do it. This one just gets all the options and then gets out of your way.

For the most part, your command-line options will probably be one of two things:
a toggle (or maybe a counter), or a key/value pair. Opt::Imistic assumes this
and parses your options. If you need more control over it, Opt::Imistic is not
for you and you might want to try a module such as L<Getopt::Long>.

The hash C<%Opt::Imistic::opts> contains your arguments. The argument name is
provided as the key and the value is provided as the value. If the argument
appeared multiple times, the values are grouped under the same key as an array
ref. If you use the same argument multiple times and sometimes without a value
then that instance of the option will be represented as undef. If you provide
the option multiple times and none has a value then your value is the count of
the number of times the option appeared.

Long options start with C<-->. Short options are single letters and start with
C<->. Multiple short options can be grouped without repeating the C<->.
Currently the value I<must> be separated from the option letter in the case of
short options; but for long options, both whitespace and a single C<=> are
considered delimiters.

The options are considered to stop on the first argument that does not start
with a C<-> and cannot be construed as the value to an option. You can use the
standard C<--> to force the end of option parsing. Everything after the last
option goes under the special key C<->, which can never be an option name. These
are also left on @ARGV so that C<< <> >> still works.

Examples help

    script.pl -abcde

    a => 1
    b => 1
    c => 1
    d => 1
    e => 1

That one's obvious.

    script.pl -a foo.pl

    a => 'foo.pl'

    @ARGV = ()

Z<>

    script.pl -a -- foo.pl

    a => 1
    - => 'foo.pl'

    @ARGV = ('foo.pl')

Z<>
    
    script.pl -foo

    f => 1
    o => 2

Z<>

    script.pl -foo bar

    f => 1
    o => [undef, 'bar']
    
Z<>

    script.pl --foo bar --foo=bar

    foo => ['bar', 'bar']

Z<>    

=head1 BUGS AND TODOS

No known bugs, but undesirable behaviour should be reported.

Please note the TODO list first:

=over

=item Implement hints to the parser to allow single options not to require
delimiting from their values

=item Implement further hints to alias options.

=item Implement a required list and a usage string

=back

=head1 AUTHOR

Altreus <altreus@perl.org>

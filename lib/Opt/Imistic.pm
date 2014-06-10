# ABSTRACT: Very quick and simple and unobtrusive option parser
package Opt::Imistic;
use strict;
use warnings;

our $VERSION = 0.03;

package Opt::Imistic::Option {
    use overload
        '""' => sub { $_[0]->[-1] },
        'bool' => sub { 1 }
}

my $putback = 0;
my %hints;

sub import {
    my $package = shift;

    {
        no warnings qw(uninitialized numeric);
        if (int $_[0] == $_[0]) {
            $putback = shift;
        }
    }

    %hints = @_;

    if ($putback and @ARGV < $putback) {
        _not_enough_args();
    }

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

            if (defined(my $val = _can_has_value())) {
                _store(pop @opts, $val);
            }
            elsif (exists $hints{needs_val}{$arg} || exists $hints{demand}{$arg}) {
				my $die_message = "%s: value required but none given\n";
				$die_message .= "\n" . $hints{usage} if exists $hints{usage};

				die sprintf $die_message, $arg;
			}

            _store($_) for @opts;
        }
        else {
            # Put it back if options have ended.
            unshift @ARGV, $arg;
            last;
        }
    }

    for my $o ( keys %ARGV ) {
        # All args are arrayrefs now. This implements tm604's suggestion that we assume
        # it's a countable option if it appears several times, but never with a value.
        $ARGV{$o} = [ scalar @{ $ARGV{$o} } ] unless grep defined, @{ $ARGV{$o} };
    }

    _store('-', $_) for @ARGV;

    if (exists $hints{demand}) {
        my $die_message = "Missing option: %s\n";
        $die_message .= "\n" . $hints{usage} if exists $hints{usage};

        for (keys %{ $hints{demand} }) {
            die sprintf($die_message, $_) unless exists $ARGV{$_};
        }
    }
}

# Stores repeated options in an array.
sub _store {
    my ($arg, $val) = @_;

    # tm604 suggested that, to accommodate an occurence such as:
    #   script --opt --opt --opt=foo --opt=123
    # we create opt => [ undef, undef, 'foo', '123' ].
    # Then we can collapse undef-only arrayrefs into counts later. So we don't
    # care if the val is undef. yay!

    $ARGV{$arg} //= bless [], "Opt::Imistic::Option";
    push @{ $ARGV{$arg} }, $val;
}

# Checks to see whether the next @ARGV is a value and returns it if so.
# shifts @ARGV so we skip it in the outer while loop. This is naughty but
# shut up :(
sub _can_has_value {
    my $val = $ARGV[0];

    if (index($val, '-') == 0 and $val ne '-') {
        # starts with - but isn't - means option. (Includes --)
        return;
    }

    if ($putback <= @ARGV) {
        # next thing is not an option; we keep this many.
        return;
    }

    if ($putback > @ARGV) {
        # next thing is not an option; not enough things left.
        _not_enough_args();
    }

    return shift @ARGV;
}

# We couldn't satisfy $putback
sub _not_enough_args {
    my $die = "Expected $putback arguments; " . @ARGV . " given\n";

    if ($hints{usage}) {
        $die .= "\n" . $hints{usage};
    }

    die $die;
}

1;

__END__

=head1 NAME

Opt::Imistic - Optimistic option parsing

=head1 SYNOPSIS

    use Opt::Imistic;
    die if $ARGV{exit};

=head1 

=head1 DESCRIPTION

Most option parsers end up doing the same thing but you have to write a whole
spec to do it. This one just gets all the options and then gets out of your way.

For the most part, your command-line options will probably be one of two things:
a toggle (or maybe a counter), or a key/value pair. Opt::Imistic assumes this
and parses your options. If you need more control over it, Opt::Imistic is not
for you and you might want to try a module such as L<Getopt::Long>.

The hash C<%ARGV> contains your arguments. The argument name is provided as the
key and the value is provided as the value. If you use the same argument
multiple times and sometimes without a value then that instance of the option
will be represented as undef. If you provide the option multiple times and none
has a value then your value is the count of the number of times the option
appeared.

All arguments in C<%ARGV> are now represented as array refs, blessed into a
package that stringifies them to the last instance of that argument and
boolifies to true. That means that you can always do

    @{$ARGV}{option_name}

or

    $ARGV{option_name} =~ /cats/

or

    if ($ARGV{option_name})

without having to test what $ARGV{option_name} actually is.

This basically means that the way you use the option determines what it should
have been:

=over

=item Using it as an array ref means you expected zero or more values from it.

=item Using it as a string or number means you expected a single value out of
it.

=item Testing it means you only cared whether it was present or not.

=back

To follow convention, when you try to use an argument as a string, the end of
the internal arrayref is returned: this implements the common behaviour that the
I<last> option of the same name is honoured.

=head2 Options and arguments

Long options start with C<-->. Short options are single letters and start with
C<->. Multiple short options can be grouped without repeating the C<->, in the
familiar C<perl -lne> fashion.

For short options the value I<must> be separated from the option letter; but for
long options, both whitespace and a single C<=> are considered delimiters. This
is because Opt::Imistic doesn't take an option spec, and hence cannot
distinguish between single-letter options with values and several single-letter
options.

Repeated options with no values are counted. Repeated options with values are
concatenated in an array ref. Note that all options can be treated as array
refs.

The options are considered to stop on the first argument that does not start
with a C<-> and cannot be construed as the value to an option. You can use the
standard C<--> to force the end of option parsing. Everything after the last
option goes under the special key C<->, because that can never be an option
name. These are also left on @ARGV so that C<< <> >> still works.

Examples help

    script.pl -abcde

    a => 1
    b => 1
    c => 1
    d => 1
    e => 1

That one's obvious.

    script.pl -a foo.pl

    a => ['foo.pl']

    @ARGV = ()

Z<>

    script.pl -a -- foo.pl

    a => [ 1 ]
    - => [ 'foo.pl' ]

    @ARGV = ('foo.pl')

Z<>
    
    script.pl -foo

    f => [ 1 ]
    o => [ 2 ]

Z<>

    script.pl -foo bar

    f => [ 1 ]
    o => [undef, 'bar']
    
Z<>

    script.pl --foo bar --foo=bar

    foo => ['bar', 'bar']

Z<> 

=head1 BUGS AND TODOS

It should be noted that Opt::Imistic does not observe a difference between C<-f> and C<--f>.

No known bugs.

Please report undesirable behaviour, but note the TODO list first:

=over

=item Implement hints to the parser to allow single options not to require
delimiting from their values

=item Implement further hints to alias options.

=item Implement a required list and a usage string

=back

=head1 AUTHOR

Altreus <altreus@perl.org>

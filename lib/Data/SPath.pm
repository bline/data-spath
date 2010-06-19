use strict;
use warnings;
package Data::SPath;
BEGIN {
  $Data::SPath::VERSION = '0.0001';
}
#ABSTRACT: lookup on nested data with simple path notation

use Carp qw/croak/;
use Scalar::Util qw/reftype blessed/;
use Text::Balanced qw/ extract_delimited /;

use Sub::Exporter -setup => {
    exports => [ spath => \&_build_spath ]
};

my @Error_Handlers = qw( method_miss key_miss index_miss key_on_non_hash );


sub _build_spath {
    my ( $class, $name, $args ) = @_;

    return sub {
        my ( $data, $path, $opts ) = @_;
        for ( @Error_Handlers ) {
            unless ( exists $opts->{ $_ } ) {
                if ( exists $args->{ $_ } ) {
                    $opts->{ $_ } = $args->{ $_ };
                }
                else {
                    $opts->{ $_ } = \&{ "_$_" };
                }
            }
            no warnings 'uninitialized';
            unless ( ref( $opts->{ $_ } ) eq 'CODE' or reftype( $opts->{ $_ } ) eq 'CODE' ) {
                croak "$_ must be set to a code reference";
            }
        }
        return _spath( $data, $path, $opts );
    };
}

# taken from Data::DPath
sub _unescape {
    my ( $str ) = @_;
    return unless defined $str;
    $str =~ s/(?<!\\)\\(["'])/$1/g; # '"$
    $str =~ s/\\{2}/\\/g;
    return $str;
}

sub _quoted { shift =~ m,^/["'], }

sub _method_miss {
    my ( $method_name, $current, $depth ) = @_;
    my $reftype = reftype( $current );
    croak "tried to call nonexistent method '"
        . $method_name
        . "' on object with type $reftype at spath path element "
        . $depth;
}

sub _key_miss {
    my ( $key, $current, $depth ) = @_;
    croak "tried to access nonexistent key '"
        . $key
        . "' in hash at spath path element "
        . $depth;
}

sub _index_miss {
    my ( $index, $current, $depth ) = @_;
    croak "tried to access nonexistent index '"
        . $index
        . "' in array at spath path element "
        . $depth;
}

sub _key_on_non_hash {
    my ( $key, $current, $depth ) = @_;
    my $reftype = reftype( $current ) || '(non reference)';
    croak "tried to access key '"
        . $key
        . "' on a non-hash type $reftype at spath path element "
        . $depth;
}


sub _spath {
    my ( $data, $path, $opts ) = @_;

    my $remaining_path = $path;
    my $current = $data;
    my $depth = 0;
    my $extracted;
    my $wantlist = wantarray;

    while ( $remaining_path ) {
        $depth++;
        my $key;
        if ( _quoted( $remaining_path ) ) {
            ( $key, $remaining_path ) = extract_delimited( $remaining_path, q|'"|, '/' );
            $key = _unescape _unquote $key;
        }
        else {
            ( $extracted, $remaining_path ) = extract_delimited( $remaining_path, '/' );
            if ( not $extracted ) {
                ( $extracted, $remaining_path ) = ( $remaining_path, undef );
            }
            else {
                $remaining_path = ( chop $extracted ) . $remaining_path;
            }
            ( $key ) = $extracted =~ m,^/(.*),g;
            $key = _unescape $key;
        }

        no warnings 'uninitialized';
        if ( blessed $current ) {
            if ( my $method = $current->can( $key ) ) {
                if ( $wantlist ) {
                    my @current = $current->$method();
                    $current = @current > 1 ? \@current : $current[0];
                }
                else {
                    $current = $current->$method();
                }
            }
            else {
                return $opts->{method_miss}->( $key, $current, $depth );
            }
        }
        # optimization taken from Data::DPath
        elsif ( ref( $current ) eq 'HASH' or reftype( $current ) eq 'HASH' ) {
            if ( exists $current->{ $key } ) {
                $current = $current->{ $key };
            }
            else {
                return $opts->{key_miss}->( $key, $current, $depth );
            }
        }
        elsif ( ref( $current ) eq 'ARRAY' or reftype( $current ) eq 'ARRAY' ) {
            unless ( $key =~ /^\d+$/ ) {
                $opts->{key_on_non_hash}->( $key, $current, $depth );
            }
            if ( $#{ $current } < $key ) {
                return $opts->{index_miss}->( $key, $current, $depth );
            }
            $current = $current->[ $key ];
        }
        else {
            return $opts->{key_on_non_hash}->( $key, $current, $depth );
        }
    }
    return $current;
}


1;


__END__
=pod

=head1 NAME

Data::SPath - lookup on nested data with simple path notation

=head1 VERSION

version 0.0001

=head1 SYNOPSIS

    use Data::SPath
        spath => {
            # sets up default error handling
            method_miss => \&_method_miss,
            key_miss => \&_key_miss,
            index_miss => \&_index_miss,
            key_on_non_hash => \&_key_on_non_hash
        };

    my $data = {
        foo => [ qw/foobly fooble/ ],
        bar => [ { bat => "boo" }, { bat => "bar" } ]
    };

    my $match;

    # returns foobly
    $match = spath $data, "/foo/1";

    # returns boo
    $match = spath $data, "/bar/0/bat";

    # returns { bat => "bar" }
    $match = spath $data, "/bar/1";

=head1 DESCRIPTION

This module implements very simple path lookups on nested data structures. At
the time of this writing there are two modules that implement path matching.
They are L<Data::Path> and L<Data::DPath>. Both of these modules have more
complicated matching similar to C<XPath>. This module does not support
B<matching>, only lookups. So one call will alway return a single match. Also,
when this module encounters a C<blessed> reference, instead of access the references
internal data structure (like L<Data::DPath>) a method call is made on the object
by the name of the key. See L</SYNOPSYS>.

=head1 FUNCTIONS

=head2 C<spath( $data, $path, $opts )>

C<spath> takes the data to perform lookup on as the first argument. The second
argument should be a string with a path specification in it. The third optional
argument, if specified, should be a hash reference of options. Currently the
only supported options are error handlers.  See L</"ERROR HANDLING">. C<spath>
returns the lookup if it is found, calls croak() otherwise with the error. This
behavior can be changed by setting error handlers. If the error handler
returns, that value is returned.

=over 4

=item *

data

Data can be any type of data, although it makes little sense to pass in
something other than a hash reference, an array reference or an object.

=item *

path

Path should start with a slash and be a slash separated list of keys to match
on. Each level of key is one level deeper in the data. When the current level
in the data is a hash reference, the key is looked up in the hash, and the
current level is set to the return of the lookup on the hash. When the current
level is an array reference, the key should be an index into the array, the
current level is then set to the return of the lookup on the array reference.
If the current level is an object, the key is treated as the name of a method
to call on the object. The method is called in list context if C<spath> was
called in list context, otherwise it is called in scalar context. If the method
returns more than one thing, the current level is set to an array reference of
the return, otherwise the current level is set to the return of the method
call. See L</SYNOPSYS> for examples.

=item *

opts

The only options currently accepted are error handlers. See L</"ERROR
HANDLING">.

=back

=head1 EXPORTS

Nothing is exported by default. You can request C<spath> be exported to you
namespace.  This module uses L<Sub::Exporter> for exporting.

=head1 ERROR HANDLING

Data::SPath defaults to calling Carp::croak() when any kind of error occurs.
You can change any of the error handlers by passing in a third argument to
C<spath>:

    spath $data, "/path", {
        method_miss => \&_method_miss,
        key_miss => \&_key_miss,
        index_miss => \&_index_miss,
        key_on_non_hash => \&_key_on_non_hash
    };

Or you can setup default error handlers at compile time by passing them into
your call to C<import()>:

    use Data::SPath
        spath => {
            method_miss => \&_method_miss,
            key_miss => \&_key_miss,
            index_miss => \&_index_miss,
            key_on_non_hash => \&_key_on_non_hash
        };

The default error handlers look like this:

    sub _method_miss {
        my ( $method_name, $current, $depth ) = @_;
        my $reftype = reftype( $current );
        croak "tried to call nonexistent method '"
            . $method_name
            . "' on object with type $reftype at spath path element "
            . $depth;
    }

    sub _key_miss {
        my ( $key, $current, $depth ) = @_;
        croak "tried to access nonexistent key '"
            . $key
            . "' in hash at spath path element "
            . $depth;
    }

    sub _index_miss {
        my ( $index, $current, $depth ) = @_;
        croak "tried to access nonexistent index '"
            . $index
            . "' in array at spath path element "
            . $depth;
    }

    sub _key_on_non_hash {
        my ( $key, $current, $depth ) = @_;
        my $reftype = reftype( $current ) || '(non reference)';
        croak "tried to access key '"
            . $key
            . "' on a non-hash type $reftype at spath path element "
            . $depth;
    }

If you return from an error handler, that value is returned from C<spath>.

=head1 AUTHOR

Scott Beck <scottbeck@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Scott Beck <scottbeck@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


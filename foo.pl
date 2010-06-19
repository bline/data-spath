#!/usr/bin/env perl
use strict;
use warnings;
use Text::Balanced qw/ extract_delimited extract_bracketed extract_multiple /;

# taken from Data::DPath
sub _unescape {
    my ( $str ) = @_;
    return unless defined $str;
    $str =~ s/(?<!\\)\\(["'])/$1/g; # '"$
    $str =~ s/\\{2}/\\/g;
    return $str;
}

# Modified from Data::DPath. Added /s modifier to allow new lines in keys (why
# not?)
sub _unquote {
    my ($str) = @_;
    $str =~ s/^"(.*)"$/$1/sg;
    return $str;
}

sub _quoted { shift =~ m,^/["'], }

_spath(@ARGV);
sub _spath {
    my ( $path ) = @_;

    my $remaining_path = $path;
    my $depth = 0;
    my $extracted;
    my $wantlist = wantarray;
    my @steps;

    while ( $remaining_path ) {
        my ( $prefix, $args );
        warn "<< $remaining_path\n";
        $depth++;
        my $key;

        if ( _quoted( $remaining_path ) ) {
            ( $key,  $remaining_path ) = extract_delimited( $remaining_path, q|'"|, '/' );
            ( $args, $remaining_path ) = extract_bracketed( $remaining_path, q|('")| );
            $key = _unescape _unquote $key;

        }
        else {
            # must extract arguments first to keep extract_delimited from getting
            # quoted structures with / in them
            if ( $remaining_path =~ m,^/[^/]+\(, ) {
                ( $extracted, $remaining_path, $prefix ) = extract_bracketed( $remaining_path, q|('")|, '[^(]*' );
                if ( defined $prefix or defined $remaining_path ) {
                    no warnings 'uninitialized';
                    $remaining_path = $prefix . $remaining_path;
                    $args = $extracted;
                }
                else {
                    $remaining_path = $extracted;
                }
            }
            ( $extracted, $remaining_path ) = extract_delimited( $remaining_path, '/' );
            if ( not $extracted ) {
                ( $extracted, $remaining_path ) = ( $remaining_path, undef );
            }
            else {
                $remaining_path = ( chop $extracted ) . $remaining_path;
            }
            ( $key ) = $extracted =~ m,^/(.*),gs;
            $key = _unescape $key;
        }

        if ( defined $args ) {
            ($args) = $args =~ /^\((.*)\)$/;
            $args = [
                map { _unescape( $_ =~ /^['"]/ ? _unquote( $_ ) : $_ ) }
                    extract_multiple( $args, [
                        # quoted structures
                        sub { extract_delimited( $_[0], q|'"| ) },
                        # handle unquoted bare words
                        qr/\s*(\w+)/s,
                        qr/\s*([^,]+)(.*)/s
                    ], undef, 1 )
            ];
        }

        push @steps, [ $key, $args ];
    }
    use Data::Dumper;
    print Dumper( \@steps );
}

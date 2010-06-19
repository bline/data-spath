#!perl

use strict;
use Test::More tests => 10;

BEGIN {
    use_ok( "Data::SPath", 'spath' );
}

my $data = {
    string => "bar",
    array => [ qw/foo bar baz/ ],
    hash => { foo => 1, bar => 2 },
    regexp => qr/regex/,
    scalar => \"bar",
    object1 => TObj->new( "foo", "bar" ),
    object2 => TObj->new(
        TObj->new( "foo" ),
        TObj->new( "bar" )
    ),
    object3 => TObj->new( [qw/foo bar baz/], { foo => 1, bar => 2 } ),
    array1 => [ TObj->new("foo"), TObj->new("bar") ],
    hash1 => { boo => TObj->new("foobly"), poo => TObj->new("barbly") },
};

is( spath( $data, "/string" ), "bar", "simple string" );
is( spath( $data, "/array/0" ), "foo", "simple array" );
is( spath( $data, "/hash/foo" ), "1", "simple hash" );
is( spath( $data, "/object1/a" ), "foo", "simple object" );
is( spath( $data, "/object2/b/a" ), "bar", "object with direct objects" );
is( spath( $data, "/object3/a/0" ), "foo", "object with array" );
is( spath( $data, "/object3/b/foo" ), "1", "object with hash" );
is( spath( $data, "/array1/1/a" ), "bar", "array with object" );
is( spath( $data, "/hash1/poo/a" ), "barbly", "hash with object" );

BEGIN {
    package TObj;

    sub new { my $class = shift; bless [ @_ ], $class }
    sub a { $_[0][0] }
    sub b { $_[0][1] }
    sub c { $_[0][2] }
    sub d { $_[0][3] }
}



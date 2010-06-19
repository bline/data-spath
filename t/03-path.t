#!perl

use strict;
use Test::More 'no_plan';

BEGIN {
    use_ok( "Data::SPath", 'spath' );
}

my $data = {
    string => "bar",
    string1 => "b\"ar",
    string2 => "b\"a\"r",
    string3 => "b \"a\" r",
    string4 => "b \" a \" r",
    string5 => " ",
    string6 => " b",
    string7 => " b ",
    string8 => " b a",
    string9 => " b a ",
    string10 => " b a r",
    string11 => " b a r ",
    string12 => "b a r",
    string13 => "b \\ a r",
    string14 => "b \\ a \\ r",
    string15 => "b \\ \na\n \\ r",
    string16 => "b \\\\ \na\n \\\\ r",
    string17 => "\\\\\\\\\\",
    string18 => "\\\\\\\\",
    string19 => "\\\\\\",
    string20 => "\\\\",
    string21 => "\\",
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
    hash2 => {
        "b\"ar" => 1,
        "b\"a\"r" => 1,
        "b \"a\" r" => 1,
        "b \" a \" r" => 1,
        " " => 1,
        " b" => 1,
        " b " => 1,
        " b a" => 1,
        " b a " => 1,
         " b a r" => 1,
         " b a r " => 1,
         "b a r" => 1,
         "b \\ a r" => 1,
         "b \\ a \\ r" => 1,
         "b \\ \na\n \\ r" => 1,
         "b \\\\ \na\n \\\\ r" => 1,
         "\\\\\\\\\\" => 1,
         "\\\\\\\\" => 1,
         "\\\\\\" => 1,
         "\\\\" => 1,
         "\\" => 1,
    }
};

is( spath( $data, "/string" ), $data->{string}, "simple string" );
is( spath( $data, "/array/0" ), $data->{array}[0], "simple array" );
is( spath( $data, "/hash/foo" ), $data->{hash}{foo}, "simple hash" );
is( spath( $data, "/object1/a" ), $data->{object1}->a, "simple object" );
is( spath( $data, "/object2/b/a" ), $data->{object2}->b->a, "object with direct objects" );
is( spath( $data, "/object3/a/0" ), $data->{object3}->a->[0], "object with array" );
is( spath( $data, "/object3/b/foo" ), $data->{object3}->b->{foo}, "object with hash" );
is( spath( $data, "/array1/1/a" ), $data->{array1}->[1]->a, "array with object" );
is( spath( $data, "/hash1/poo/a" ), $data->{hash1}->{poo}->a, "hash with object" );
for ( 1 .. 21 ) {
    is( spath( $data, "/string$_" }, $data->{"string$_"} ), qq(string '$data->{"string$_"}' lookup) );
}
for ( keys %{ $data->{hash2} } ) {
    (my $cp = $_) =~ s/(["'\\])/\\$1/g;
    is( spath( $data, qq[/hash2/"$cp"] ), $data->{hash2}->{$_}, "hash key '$cp' lookup" );
}
for ( keys %{ $data } ) {
    is_deeply( spath( $data, "/$_" ), $data->{$_}, "deeply $_ lookup" );
}

BEGIN {
    package TObj;

    sub new { my $class = shift; bless [ @_ ], $class }
    sub a { $_[0][0] }
    sub b { $_[0][1] }
    sub c { $_[0][2] }
    sub d { $_[0][3] }
}



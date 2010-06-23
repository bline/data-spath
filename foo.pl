#!perl

use v5.10.0;

given($foo) {
    when (/x/) { say '$foo contains an x'; continue }
    when (/y/) { say '$foo contains a y' }
    default    { say '$foo does not contain a y' }
}

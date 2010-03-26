#! perl -T

use strict;
use warnings;

use Math::BigInt try => 'Pari';
use Test::More tests => 4;

diag( 'Tried Pari. Got ' . Math::BigInt->config()->{ lib } . ' ' . Math::BigInt->config()->{ lib_version });
ok(1, 'Tried Pari. Got ' . Math::BigInt->config()->{ lib } . ' ' . Math::BigInt->config()->{ lib_version });

SKIP: {
    skip("Didn't get Pari", 3)
        unless Math::BigInt->config()->{ lib } eq 'Math::BigInt::Pari';
    my $big_number = Math::BigInt->from_hex('0x' . 'f' x 32);
    my $small_number = $big_number & Math::BigInt->from_hex('0xffffffff');
    my $not_zero = $big_number & Math::BigInt->from_hex('0xffff00000000');
    ok($small_number->as_hex() eq '0xffffffff', "BigInt round trip");
    ok($not_zero != 0, "Not zero");
    ok($not_zero != hex('0xffffffff'), "Not all effs");
}


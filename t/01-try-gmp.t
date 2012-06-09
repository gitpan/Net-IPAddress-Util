#! perl -T

use strict;
use warnings;

use Data::Dumper;
use Net::IPAddress::Util try => 'GMP', ':all';
use Net::IPAddress::Util::Range;
use Net::IPAddress::Util::Collection;
use Test::More tests => 5;
use Time::HiRes qw(time);

diag( 'Tried GMP. Got ' . Math::BigInt->config()->{ lib } . ' ' . Math::BigInt->config()->{ lib_version });
ok(1, 'Tried GMP. Got ' . Math::BigInt->config()->{ lib } . ' ' . Math::BigInt->config()->{ lib_version });

SKIP: {
    skip("Didn't get GMP", 3)
        unless Math::BigInt->config()->{ lib } eq 'Math::BigInt::GMP';
    my $big_number = Math::BigInt->from_hex('0x' . 'f' x 32);
    my $small_number = $big_number & Math::BigInt->from_hex('0xffffffff');
    my $not_zero = $big_number & Math::BigInt->from_hex('0xffff00000000');
    ok($small_number->as_hex() eq '0xffffffff', "BigInt round trip");
    ok($not_zero != 0, "Not zero");
    ok($not_zero != hex('0xffffffff'), "Not all effs");
}

if (!$ENV{IP_UTIL_TIME_TRIALS}) {
    diag('Set $ENV{IP_UTIL_TIME_TRIALS} if you want time trials.');
    ok('Skipped time trials');
}
elsif (Math::BigInt->config()->{ lib } ne 'Math::BigInt::GMP') {
    ok('Skipped GMP time trials (backend not installed)');
}
else {
    diag('This is going to take a while. Unset $ENV{IP_UTIL_TIME_TRIALS} if you don\'t want time trials.');
    diag('Using ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });
    {
        my $j = 500;
        my $savings;
        while (1) {
            my $count = int($j);
            my @to_sort;
            for my $i (1 .. $count) {
                my $a = int(rand(256));
                my $b = int(rand(256));
                my $c = int(rand(256));
                my $d = int(rand(256));
                push @to_sort, Net::IPAddress::Util->new("$a.$b.$c.$d");
            }
            my ($r, $tr, $p, $tp);
            {
                $r = time;
                my @rsorted = radix_sort(@to_sort);
                $tr = time - $r;
            }
            {
                $p = time;
                my @psorted = sort { $a <=> $b } @to_sort;
                $tp = time - $p;
            }
            $savings = int((($tp - $tr) / $tp) * 1000) / 10;
            last if abs($savings) < 1 && $savings < 0;
            $j *= (($tr - $tp) / $tp);
            $j = int(abs($j)) || 1;
        }
        $savings = 0 - $savings;
        diag("Found break-even point for IPv4 ($j is $savings\% faster)");
    }
    {
        my $j = 500;
        my @digits = qw( 0 1 2 3 4 5 6 7 8 9 a b c d e f );
        my $savings;
        while (1) {
            my $count = int($j);
            my @to_sort;
            for my $i (1 .. $count) {
                my $plen = int(rand(12)) + 1;
                my $slen = int(rand(12)) + 1;
                my $mlen = 32 - ($plen + $slen);
                my $x = '';
                for (1 .. $plen) {
                    $x .= $digits[ rand @digits ];
                }
                $x .= '0' x $mlen;
                for (1 .. $slen) {
                    $x .= $digits[ rand @digits ];
                }
                push @to_sort, Net::IPAddress::Util->new($x);
            }
            my ($r, $tr, $p, $tp);
            {
                $r = time;
                my @rsorted = radix_sort(@to_sort);
                $tr = time - $r;
            }
            {
                $p = time;
                my @psorted = sort { $a <=> $b } @to_sort;
                $tp = time - $p;
            }
            $savings = int((($tp - $tr) / $tp) * 1000) / 10;
            last if abs($savings) < 1 && $savings < 0;
            $j *= (($tr - $tp) / $tp);
            $j = int(abs($j)) || 1;
        }
        $savings = 0 - $savings;
        diag("Found break-even point for IPv6 ($j is $savings\% faster)");
    }
    {
        for my $n (map { int(10 ** ($_ / 2)) } 2 .. 10) {
            my @to_sort;
            my $savings;
            for my $i (1 .. $n) {
                my $la = int(rand(256));
                my $lb = int(rand(256));
                my $lc = int(rand(256));
                my $ld = int(rand(256));
                my $lo = Net::IPAddress::Util->new("$la.$lb.$lc.$ld");
                my $ha = int(rand(256));
                my $hb = int(rand(256));
                my $hc = int(rand(256));
                my $hd = int(rand(256));
                my $hi = Net::IPAddress::Util->new("$ha.$hb.$hc.$hd");
                push @to_sort, Net::IPAddress::Util::Range->new({ lower => $lo, upper => $hi });
            }
            my $to_sort = Net::IPAddress::Util::Collection->new(@to_sort);
            my ($r, $tr, $p, $tp);
            my $j = $n / 2;
            while (1) {
                my $was_using_radix = $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
                {
                    undef $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
                    $p = time;
                    my $psorted = $to_sort->sorted();
                    $tp = time - $p;
                }
                {
                    $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $j;
                    $r = time;
                    my $rsorted = $to_sort->sorted();
                    $tr = time - $r;
                }
                $savings = int((($tp - $tr) / $tp) * 1000) / 10;
                $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $was_using_radix;
                last if (($j == 1 || abs($savings) < 1) && $savings < 0) || $j > $n;
                $j *= (($tr - $tp) / $tp);
                $j = int(abs($j)) || 1;
            }
            if ($j == 1 and $n == 10) {
                diag("Sorting any size collection of IPv4 ranges, setting \$RADIX_THRESHOLD is always faster");
                last;
            }
            elsif ($j > $n) {
                diag("Sorting any size collection of IPv4 ranges, setting \$RADIX_THRESHOLD is always SLOWER!");
                last;
            }
            else {
                $savings = 0 - $savings;
                diag("Sorting a collection of $n random IPv4 ranges, setting \$RADIX_THRESHOLD to $j was $savings\% faster");
            }
        }
    }
    {
        my @digits = qw( 0 1 2 3 4 5 6 7 8 9 a b c d e f );

        for my $n (map { int(10 ** ($_ / 2)) } 2 .. 10) {
            my @to_sort;
            my $savings;
            for my $i (1 .. $n) {
                my $lo;
                {
                    my $plen = int(rand(12)) + 1;
                    my $slen = int(rand(12)) + 1;
                    my $mlen = 32 - ($plen + $slen);
                    my $x = '';
                    for (1 .. $plen) {
                        $x .= $digits[ rand @digits ];
                    }
                    $x .= '0' x $mlen;
                    for (1 .. $slen) {
                        $x .= $digits[ rand @digits ];
                    }
                    $lo = Net::IPAddress::Util->new($x);
                }
                my $hi;
                {
                    my $plen = int(rand(12)) + 1;
                    my $slen = int(rand(12)) + 1;
                    my $mlen = 32 - ($plen + $slen);
                    my $x = '';
                    for (1 .. $plen) {
                        $x .= $digits[ rand @digits ];
                    }
                    $x .= '0' x $mlen;
                    for (1 .. $slen) {
                        $x .= $digits[ rand @digits ];
                    }
                    $hi = Net::IPAddress::Util->new($x);
                }
                push @to_sort, Net::IPAddress::Util::Range->new({ lower => $lo, upper => $hi });
            }
            my $to_sort = Net::IPAddress::Util::Collection->new(@to_sort);
            my ($r, $tr, $p, $tp);
            my $j = $n / 2;
            while (1) {
                my $was_using_radix = $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
                {
                    undef $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
                    $p = time;
                    my $psorted = $to_sort->sorted();
                    $tp = time - $p;
                }
                {
                    $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $j;
                    $r = time;
                    my $rsorted = $to_sort->sorted();
                    $tr = time - $r;
                }
                $savings = int((($tp - $tr) / $tp) * 1000) / 10;
                $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $was_using_radix;
                last if (($j == 1 || abs($savings) < 1) && $savings < 0) || $j > $n;
                $j *= (($tr - $tp) / $tp);
                $j = int(abs($j)) || 1;
            }
            if ($j == 1 and $n == 10) {
                diag("Sorting any size collection of IPv6 ranges, setting \$RADIX_THRESHOLD is always faster");
                last;
            }
            elsif ($j > $n) {
                diag("Sorting any size collection of IPv4 ranges, setting \$RADIX_THRESHOLD is always SLOWER!");
                last;
            }
            else {
                $savings = 0 - $savings;
                diag("Sorting a collection of $n random IPv6 ranges, setting \$RADIX_THRESHOLD to $j was $savings\% faster");
            }
        }
    }
    ok('Ran time trials');
}


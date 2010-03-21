#! perl -T

use strict;
use warnings;

use Data::Dumper;
use Net::IPAddress::Util try => 'GMP,Pari', ':all';
use Net::IPAddress::Util::Range;
use Net::IPAddress::Util::Collection;
use Test::More tests => 1;
use Time::HiRes qw(time);

if (!$ENV{IP_UTIL_TIME_TRIALS}) {
    diag('Set $ENV{IP_UTIL_TIME_TRIALS} if you want time trials.');
    ok('Skipped time trials');
}
else {
    diag('This is going to take a while. Unset $ENV{IP_UTIL_TIME_TRIALS} if you don\'t want time trials.');
    diag('Using ' . Net::IPAddress::Util->config()->{ lib } . ' ' . IPAddress::Simple->config()->{ lib_version });
    {
        my $j = 500;
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
            my $savings = int((($tp - $tr) / $tp) * 1000) / 10;
            my $rper = int(1000000 * $tr / $count);
            my $pper = int(1000000 * $tp / $count);
            my $adverb = $savings < 0 ? 'slower' : 'faster';
            $savings = abs($savings);
            diag("Sorting $count random IPv4 addresses, radix_sort() was $savings\% $adverb (${rper} vs ${pper} µs)");
            $j *= 2 * ($tr / $tp);
            last if $adverb eq 'faster';
        }

        diag("Found break-even point for IPv4, starting IPv6");

        my @digits = qw( 0 1 2 3 4 5 6 7 8 9 a b c d e f );

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
            my $savings = int((($tp - $tr) / $tp) * 1000) / 10;
            my $rper = int(1000000 * $tr / $count);
            my $pper = int(1000000 * $tp / $count);
            my $adverb = $savings < 0 ? 'slower' : 'faster';
            $savings = abs($savings);
            diag("Sorting $count random IPv6 addresses, radix_sort() was $savings\% $adverb (${rper} vs ${pper} µs)");
            $j *= 2 * ($tr / $tp);
            last if $adverb eq 'faster';
        }

        diag("Found break-even point for IPv6, starting IPv4 Collections");

    }
    {
        for my $n (1 .. 10) {
            my $j = $n * 500;
            my @to_sort;
            for my $i (1 .. $j) {
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
            my $was_using_radix = $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
            {
                undef $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
                $p = time;
                my $psorted = $to_sort->sorted();
                $tp = time - $p;
            }
            {
                $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $j / 10;
                $r = time;
                my $rsorted = $to_sort->sorted();
                $tr = time - $r;
            }
            my $savings = int((($tp - $tr) / $tp) * 1000) / 10;
            my $adverb = $savings < 0 ? 'slower' : 'faster';
            $savings = abs($savings);
            diag("Sorting a Collection of $j random IPv4 ranges, setting \$RADIX_THRESHOLD to ${Net::IPAddress::Util::Collection::RADIX_THRESHOLD} was $savings\% $adverb");
            $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $was_using_radix;
        }
    }
    {
        for my $n (1 .. 10) {
            my $j = $n * 500;
            my @to_sort;
            for my $i (1 .. $j) {
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
            my $was_using_radix = $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
            {
                undef $Net::IPAddress::Util::Collection::RADIX_THRESHOLD;
                $p = time;
                my $psorted = $to_sort->sorted();
                $tp = time - $p;
            }
            {
                $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = 1;
                $r = time;
                my $rsorted = $to_sort->sorted();
                $tr = time - $r;
            }
            my $savings = int((($tp - $tr) / $tp) * 1000) / 10;
            my $adverb = $savings < 0 ? 'slower' : 'faster';
            $savings = abs($savings);
            diag("Sorting a Collection of $j random IPv4 ranges, setting \$RADIX_THRESHOLD to ${Net::IPAddress::Util::Collection::RADIX_THRESHOLD} was $savings\% $adverb");
            $Net::IPAddress::Util::Collection::RADIX_THRESHOLD = $was_using_radix;
        }
    }
    ok('Ran time trials');
}


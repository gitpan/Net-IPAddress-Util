#! perl -T

use strict;
use warnings;

use Net::IPAddress::Util try => 'GMP,Pari', ':all';
use Net::IPAddress::Util::Range;
use Net::IPAddress::Util::Collection;
use Test::More tests => 41;
use Time::HiRes qw(time);

$Net::IPAddress::Util::DIE_ON_ERROR = 1;

{
    my $test = Net::IPAddress::Util->new('192.168.0.1');
    my $nf = $test->normal_form();
    is($test->str() ,        '192.168.0.1', "Pure IPv4 round-trip via str()");
    is("$test"      ,        '192.168.0.1', "Pure IPv4 round-trip overloaded");
    is($test->ipv4(),        '192.168.0.1', "Pure IPv4 round-trip via ipv4()");
    is($test->ipv6(), '::ffff:192.168.0.1', "Pure IPv4 round-trip via ipv6()");
    is($nf          , '00000000000000000000ffffc0a80001', "Pure IPv4 round-trip normal form");
}

{
    my $test = Net::IPAddress::Util->new('::ffff:192.168.0.1');
    my $nf = $test->normal_form();
    is("$test" , '192.168.0.1', "IPv4-in-IPv6 round-trip");
    is($nf , '00000000000000000000ffffc0a80001', "IPv4-in-IPv6 round-trip normal form");
}

{
    my $test = Net::IPAddress::Util->new('::ffff:c0a8:0001');
    my $nf = $test->normal_form();
    is("$test" , '192.168.0.1', "IPv4-as-IPv6 round-trip");
    is($nf , '00000000000000000000ffffc0a80001', "IPv4-as-IPv6 round-trip normal form");
}

{
    my $test = Net::IPAddress::Util->new('12::34');
    my $nf = $test->normal_form();
    is("$test" , '12::34', "Pure IPv6 round-trip");
    is($nf , '00120000000000000000000000000034', "Pure IPv6 round-trip normal form");
}

{
    my $lower = Net::IPAddress::Util->new('192.168.0.1');
    my $upper = Net::IPAddress::Util->new('192.168.0.1');
    my $range = Net::IPAddress::Util::Range->new({ lower => $lower, upper => $upper });
    my $bounds = $range->outer_bounds();
    is("$range"              , '(192.168.0.1 .. 192.168.0.1)', "Single IPv4 range");
    is("$bounds->{ base }"   , '192.168.0.1', "Single IPv4 base");
    is("$bounds->{ highest }", '192.168.0.1', "Single IPv4 highest");
    is("$bounds->{ netmask }", '255.255.255.255', "Single IPv4 netmask");
    is("$bounds->{ cidr }"   , '32', "Single IPv4 cidr");
}

{
    my $lower = Net::IPAddress::Util->new('12::34');
    my $upper = Net::IPAddress::Util->new('12::34');
    my $range = Net::IPAddress::Util::Range->new({ lower => $lower, upper => $upper });
    my $bounds = $range->outer_bounds();
    is("$range"              , '(12::34 .. 12::34)', "Single IPv6 range");
    is("$bounds->{ base }"   , '12::34', "Single IPv6 base");
    is("$bounds->{ highest }", '12::34', "Single IPv6 highest");
    is("$bounds->{ netmask }", 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff', "Single IPv6 netmask");
    is("$bounds->{ cidr }"   , '128', "Single IPv6 cidr");
}

{
    my $lower = Net::IPAddress::Util->new('192.168.0.3');
    my $upper = Net::IPAddress::Util->new('192.168.0.123');
    my $range = Net::IPAddress::Util::Range->new({ lower => $lower, upper => $upper });
    my $bounds = $range->outer_bounds();
    is("$range"              , '(192.168.0.3 .. 192.168.0.123)', "Large-range range");
    is("$bounds->{ base }"   , '192.168.0.0', "Large-range base");
    is("$bounds->{ highest }", '192.168.0.127', "Large-range highest");
    is("$bounds->{ netmask }", '255.255.255.128', "Large-range netmask");
    is("$bounds->{ cidr }"   , '25', "Large-range cidr");
    my $tight = $range->tight();
    ok(scalar @{$tight} == 9, "Large-range tight size");
    my $compacted = Net::IPAddress::Util::Collection->new(@{$tight})->compacted();
    ok(scalar @{$compacted} == 1, "Large-range collection from tight, compacted");
    my $coll_t = $compacted->tight();
    ok(scalar @{$coll_t} == 9, "Round and round we go...");
    ok(scalar $coll_t->as_ranges()   == 9, "Round and round we go... (as ranges)");
    ok(scalar $coll_t->as_cidrs()    == 9, "Round and round we go... (as cidrs)");
    ok(scalar $coll_t->as_netmasks() == 9, "Round and round we go... (as netmasks)");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '192.168.0.1' });
    is("$range" , '(192.168.0.1 .. 192.168.0.1)', "Single IPv4 range via 'ip' argument");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '192.168.0.1/32' });
    is("$range" , '(192.168.0.1 .. 192.168.0.1)', "Single IPv4 range via cidrish 'ip' argument");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '1::1/128' });
    is("$range" , '(1::1 .. 1::1)', "Single IPv6 range via cidrish 'ip' argument");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '1::/120' });
    is("$range" , '(1:: .. 1::ff)', "Large IPv6 range via cidrish 'ip' argument");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '192.168.0.0/24' });
    is("$range" , '(192.168.0.0 .. 192.168.0.255)', "Large IPv4 range via cidrish 'ip' argument");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '192.168.0.0', cidr => '24' });
    is("$range" , '(192.168.0.0 .. 192.168.0.255)', "Large IPv4 range via 'cidr' argument");
}

{
    my $range = Net::IPAddress::Util::Range->new({ ip => '192.168.0.0', netmask => '255.255.255.0' });
    is("$range" , '(192.168.0.0 .. 192.168.0.255)', "Large IPv4 range via 'netmask' argument");
}

{
    local $Net::IPAddress::Util::PROMOTE_N32 = 1;
    my $ip = Net::IPAddress::Util->new(3232235521);
    is("$ip", '192.168.0.1', 'PROMOTE_N32');
    is($ip->as_n32(), 3232235521, 'as_n32()');
}



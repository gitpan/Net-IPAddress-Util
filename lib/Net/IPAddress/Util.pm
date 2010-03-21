package Net::IPAddress::Util;

use strict;

use base qw(Math::BigInt);

use Carp qw(carp cluck confess);
use Exporter;
use Regexp::IPv6 qw($IPv6_re);

use overload '""' => \&str;

our %EXPORT_TAGS = (
    constr => [qw( IP n32_to_ipv4 )],
    manip  => [qw( explode_ip implode_ip ip_pad_prefix common_prefix prefix_mask )],
    sort   => [qw( radix_sort )],
    compat => [qw( ip2num num2ip validaddr mask fqdn )]
);

my %EXPORT_OK;
for my $k (keys %EXPORT_TAGS) {
    for my $v (@{$EXPORT_TAGS{$k}}) {
        $EXPORT_OK{$v} = 1;
    }
}

our @EXPORT_OK = keys %EXPORT_OK;

$EXPORT_TAGS{ all } = [@EXPORT_OK];

our $DIE_ON_ERROR;

our $VERSION = '0.03';

sub import {
    my $pkg = shift;
    my @args = @_;
    my @bigint_keys = qw( lib try only );
    my @bigint_tags = qw( :constants );
    my @bigint_args;
    my @export_args;
    while (my $arg = shift @args) {
        if (grep {$_ eq $arg} @bigint_keys) {
            my $value = shift @args;
            push @bigint_args, ($arg => $value);
        }
        elsif (grep {$_ eq $arg} @bigint_tags) {
            push @bigint_args, $arg;
        }
        else {
            push @export_args, $arg;
        }
    }
    Math::BigInt::import($pkg, @bigint_args);
    Exporter::import($pkg, @export_args);
    Exporter::export_to_level($pkg, 1, $pkg, @export_args);
    return 1;
}

{

    my $IPV4_LO = Math::BigInt->from_hex('0xffff00000000');
    my $IPV4_HI = Math::BigInt->from_hex('0xffffffffffff');

    sub is_ipv4 {
        my $self = shift;
        return ($self >= $IPV4_LO && $self <= $IPV4_HI);
    }

    sub n32_to_ipv4 {
        my $self = shift;
        $self = __PACKAGE__->new($self) unless ref $self;
        $self |= $IPV4_LO;
        $self &= $IPV4_HI;
        return $self;
    }

}

sub IP { __PACKAGE__->new(@_) }

sub new {
    my $class   = shift;
    my $address = shift;

    my $num;

    if ($address =~ /^[0-9a-f]{32}$/) {
        # new() from result of ->normal_form()
        $address = '0x' . $address;
        $num = Math::BigInt->from_hex($address);
    }
    elsif ($address =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
        # new() from dotted-quad IPv4 address
        my $hex = '0xffff'.sprintf('%02x%02x%02x%02x', $1, $2, $3, $4);
        $num = Math::BigInt->from_hex($hex);
    }
    elsif ($address =~ /^($IPv6_re)(?:\%.*)?$/ms) {
        # new() from IPv6 address, accepting and ignoring the Scope ID
        $address = $1;
        my ($upper, $lower) = split /::/, $address;
        $lower = '' unless defined $lower;
        my $hex = '0' x 32;
        $upper =~ s/://g;
        $lower =~ s/://g;
        my $missing = 4 - (length($upper) % 4);
        $missing = 0 if $missing == 4;
        $upper = ('0' x $missing) . $upper;
        substr($hex, 0,                length($upper)) = $upper;
        substr($hex, - length($lower), length($lower)) = $lower;
        $hex = '0x'. $hex;
        $num = Math::BigInt->from_hex($hex);
    }
    else {
        # new() from bare scalar. You're on your own here, good luck.
        $num = Math::BigInt->new($address);
    }

    return bless $num => $class;
}

sub ipv4 {
    my $self = shift;
    return ERROR('Not an IPv4 adddress') unless $self->is_ipv4();
    return join '.', unpack 'C4', pack 'N32', $self;
}

sub normal_form {
    my $self = shift;
    my $hex = $self->as_hex();
    $hex =~ s/^0x//;
    $hex = substr(('0' x 32) . $hex, -32);
    return lc $hex;
}

sub ipv6_expanded {
    my $self = shift;
    my $hex = $self->normal_form();
    my $rv;
    while ($hex =~ /(....)/g) {
        $rv .= ':' if defined $rv;
        $rv .= $1;
    }
    return $rv;
}

sub ipv6 {
    my $self = shift;
    if ($self->is_ipv4()) {
        return '::ffff:'.$self->ipv4();
    }
    my $rv = $self->ipv6_expanded();
    $rv =~ s/(0000:)+/:/;
    $rv =~ s/^0+//;
    $rv =~ s/::0+/::/;
    $rv =~ s/^:/::/;
    return $rv;
}

sub str {
    my $self = shift;
    if ($self->is_ipv4()) {
        return $self->ipv4();
    }
    return $self->ipv6();
}

sub ERROR {
    my $msg = @_ ? shift() : 'An error has occured';
    if ($DIE_ON_ERROR) {
        confess($msg);
    }
    else {
        cluck($msg) if $^W;
    }
    return;
}

sub explode_ip {
    my $self = shift;
    my $str = $self->as_bin();
    $str =~ s/^0b//;
    $str = substr('0' x 128 . $str, -128);
    return split '', $str;
}

sub implode_ip {
    my @array = @_;
    my $self = __PACKAGE__->new(__PACKAGE__->from_bin('0b'. join '', @array));
    return $self;
}

sub common_prefix (\@\@) {
    my ($x, $y) = @_;
    return ERROR("Something isn't right there") unless @$x == @$y;
    my @rv;
    for my $i ($[ .. $#$x) {
        if($x->[$i] == $y->[$i]) {
            push @rv, $x->[$i];
        }
        else {
            last;
        }
    }
    return @rv;
}

sub prefix_mask (\@\@) {
    my ($x, $y) = @_;
    return ERROR("Something isn't right there") unless @$x == @$y;
    my @rv;
    for my $i ($[ .. $#$x) {
        if($x->[$i] == $y->[$i]) {
            push @rv, 1;
        }
        else {
            last;
        }
    }
    return @rv;
}

sub ip_pad_prefix {
    my @array = @_;
    my $n = scalar @array;
    return @array if $n == 128;
    for my $i ($n .. 127) {
        push @array, 0;
    }
    return @array;
}

sub radix_sort {
    # In theory, a raw radix sort is O(N), which beats Perl's O(N log N) by
    # a fair margin. However, the overhead of transforming to (and from)
    # normal form makes this only real-world faster for large arrays. On my
    # personal test system, the break-even point for IPv4 addresses is
    # somewhere between 750 and 1000 elements, and for IPv6 it's very much
    # more than that, to the point where the system starts paging.
    # TODO fork() into one bucket per CPU, and mergesort the result?
    my %index = map { $_->normal_form() => $_ } @_;
    my $from = [keys %index];
    my $to;
    for (my $i = 30; $i >= 0; $i -= 2) {
        $to = [];
        for my $card (@$from) {
            push @{$to->[hex(substr $card, $i, 2)]}, $card;
        }
        $from = [map { @{ $_ || [] } } @$to];
    }
    return map { $index{$_} } @$from;
}

sub ip2num {
    carp('Compatibility function ip2num() is deprecated') if $^W;
    my $ip = shift;
    my $self = __PACKAGE__->new($ip);
    $self &= hex('0xffffffff');
    return $self->as_int();
}

sub num2ip {
    carp('Compatibility function num2ip() is deprecated') if $^W;
    my $num = shift;
    my $self = n32_to_ipv4($num);
    return $self->str();
}

sub validaddr {
    carp('Compatibility function validaddr() is deprecated') if $^W;
    my $ip = shift;
    my @octets = split(/\./, $ip);
    return unless scalar @octets == 4;
    for (@octets) {
        return unless defined $_ && $_ >= 0 && $_ <= 255;
    }
    return 1;
}

sub mask {
    carp('Compatibility function mask() is deprecated') if $^W;
    my ($ip, $mask) = @_;
    my $self = __PACKAGE__->new($ip);
    my $nm   = __PACKAGE__->new($mask);
    $self &= hex('0xffffffff');
    $nm   &= hex('0xffffffff');
    return $self & $nm;
}

sub fqdn {
    carp('Compatibility function fqdn() is deprecated') if $^W;
    my $dn = shift;
    return split /\./, $dn, 2;
}

1;

__END__

=head1 NAME

Net::IPAddress::Util - Version-agnostic representation of an IP address

=head1 VERSION

Version 0.03

=head1 SYNOPSIS

    use Net::IPAddress::Util try => 'GMP,Pari', qw( IP );

    my $ipv4  = IP('192.168.0.1');
    my $ipv46 = IP('::ffff:192.168.0.1');
    my $ipv6  = IP('fe80::1234:5678:90ab');

    print "$ipv4\n";  # 192.168.0.1
    print "$ipv46\n"; # 192.168.0.1
    print "$ipv6\n";  # fe80::1234:5678:90ab

    print $ipv4->normal_form()  . "\n"; # 00000000000000000000ffffc0a80001
    print $ipv46->normal_form() . "\n"; # 00000000000000000000ffffc0a80001
    print $ipv6->normal_form()  . "\n"; # fe8000000000000000001234567890ab

    for (my $ip = IP('192.168.0.0'); $ip <= IP('192.168.0.255'); $ip++) {
        # do something with $ip
    }

=head1 DESCRIPTION

The goal of the Net::IPAddress::Util modules is to make IP addresses easy to
deal with, regardless of whether they're IPv4 or IPv6, and regardless of the
source (and destination) of the data being manipulated. The module
Net::IPAddress::Util is for working with individual addresses,
Net::IPAddress::Util::Range is for working with individual ranges of
addresses, and Net::IPAddress::Util::Collection is for working with
collections of addresses and/or ranges.

=head1 BACKEND LIBRARIES

This module subclasses Math::BigInt, and can take the same arguments to
control the choice of backend math libraries, specifically C<try>, C<lib>,
and C<only>. In order, these will silently fail, fail with warn(), or fail
with die(), if the specified backend librar(y|ies) cannot be loaded. The
default backend (which will be fallen back to if your specified backend(s)
cannot be loaded) is C<FastCalc>, or C<Calc> if C<FastCalc> is not available.

=head2 CHOOSING A BACKEND

Rule 1 is "profile before optimizing". Rule 2 is "your mileage may vary".
Rule 3 is "your users' mileage almost certainly will vary".

A general guideline seems to be that you can safely stick with the default
if you're going to be using IPv4 addresses, or if you wont need to search &
sort IPv6 addresses, but for searching and sorting large numbers of IPv6
addresses, you should at least try one or both of C<GMP> and C<Pari>, and
consider testing the relative speed of C<radix_sort()> on your platform.

=head1 GLOBAL VARIABLES

=head2 $Net::IPAddress::Util::DIE_ON_ERROR

Set to a true value to make errors confess(). Set to a false value to make
errors cluck(). Defaults to false.

=head1 EXPORTABLE FUNCTIONS

=head2 explode_ip

=head2 implode_ip

Transform an IP address to and from an array of 128 bits, MSB-first.

=head2 common_prefix

Given two bit arrays (as provided by C<explode_ip>), return the truncated
bit array of the prefix bits those two arrays have in common.

=head2 prefix_mask

Given two bit arrays (as provided by C<explode_ip>), return a truncated bit
array of ones of the same length as the shared C<common_prefix> of the two
arrays.

=head2 ip_pad_prefix

Take a truncated bit array, and right-pad it with zeroes to the appropriate
length.

=head2 radix_sort

Given an array of objects, sorts them in ascending order, faster than Perl's
built-in sort command.

Note that this may only be faster for sufficiently large arrays, due to the
overhead involved in setting up the radix sort.

Note also that radix_sort() discards duplicate addresses.

=head1 COMPATIBILITY API

=head2 ip2num

=head2 num2ip

=head2 validaddr

=head2 mask

=head2 fqdn

These functions are exportable to provide a functionally-identical API
to that provided by C<Net::IPAddress>. They will cause warnings to be issued
if they are called, to help you in your transition to Net::IPAddress::Util,
if indeed that's what you're doing -- and I can't readily imagine any other
reason you'd want to export them from here (as opposed to from Net::IPAddress)
unless that's indeed what you're doing.

=head1 EXPORT TAGS

=head2 :constr

Exports IP() and n32_to_ipv4(), both useful for creating objects based on
arbitrary external data.

=head2 :manip

Exports the functions for low-level "bit-twiddling" of addresses. You very
probably don't need these unless you're writing your own equivalent of the
Net::IPAddress::Util::Range or Net::IPAddress::Util::Collection modules.

=head2 :sort

Exports radix_sort(). You only need this if you're dealing with very large
arrays of Net::IPAddress::Util objects, and runtime is of critical concern.
Even then, you should profile before optimizing -- radix_sort() can be very
much slower, instead of very much faster, under the wrong circumstances.

=head2 :compat

Exports the Compatibility API functions listed above.

=head2 :all

Exports all exportable functions.

=head1 CONSTRUCTORS

=head2 new

Create a new Net::IPAddress::Util object, based on a well-formed IPv4 or IPv6
address string (e.g. '192.168.0.1' or 'fe80::1234:5678:90ab'), or based
on what is known by this module as the "normal form", a 32-digit hex number
(without the leading '0x').

=head2 IP

The exportable function IP() is a shortcut for Net::IPAddress::Util->new().

    my $xyzzy = Net::IPAddress::Util->new($foo);
    my $plugh = IP($foo); # Exactly the same thing, but with less typing

=head2 n32_to_ipv4

The exportable function n32_to_ipv4() converts an IPv4 address in "N32"
format (i.e. a network-order 32-bit number) into an Net::IPAddress::Util
object representing the same IPv4 address.

=head1 OBJECT METHODS

=head2 is_ipv4

Returns true if this object represents an IPv4 address.

=head2 ipv4

Returns the dotted-quad representation of this object, or an error if it is
not an IPv4 address, for instance '192.168.0.1'.

=head2 ipv6

Returns the canonical IPv6 string representation of this object, for
instance 'fe80::1234:5678:90ab' or '::ffff:192.168.0.1'.

=head2 ipv6_expanded

Returns the IPv6 string representation of this object, without compressing
extraneous zeroes, for instance 'fe80:0000:0000:0000:0000:1234:5678:90ab'.

=head2 normal_form

Returns the value of this object as a zero-padded 32-digit hex string,
without the leading '0x', suitable (for instance) for storage in a database,
or for other purposes where easy, fast sorting is desirable, for instance
'fe8000000000000000001234567890ab'.

=head2 '""'

=head2 str

If this object is an IPv4 address, it stringifies to the result of C<ipv4>,
else it stringifies to the result of C<ipv6>.

=head1 INTERNAL FUNCTIONS

=head2 ERROR

Either confess()es or cluck()s the passed string based on the value of
$Net::IPAddress::Util::DIE_ON_ERROR, and if possible returns undef.

=cut


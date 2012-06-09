package Net::IPAddress::Util::Range;

use 5.010;
use strict;

use Carp qw( cluck );
use Class::Std;
use Net::IPAddress::Util qw( :constr :manip );
use Net::IPAddress::Util::Collection;
use Math::BigInt;

{
    my %lower :ATTR( :name<lower> :default<0> );
    my %upper :ATTR( :name<upper> :default<0> );

    sub BUILD {
        my ($self, $this, $arg_ref) = @_;
        if ($arg_ref->{ lower } && $arg_ref->{ upper }) {
            $lower{ $this } = Net::IPAddress::Util->new($arg_ref->{ lower });
            $upper{ $this } = Net::IPAddress::Util->new($arg_ref->{ upper });
            if ($lower{ $this } > $upper{ $this }) {
                ($lower{ $this }, $upper{ $this }) = ($upper{ $this }, $lower{ $this });
            }
            return $self;
        }
        elsif ($arg_ref->{ ip }) {
            my $ip;
            my $nm;
            if ($arg_ref->{ netmask }) {
                $ip = IP($arg_ref->{ ip      });
                $nm = IP($arg_ref->{ netmask });
                $ip = $ip & $nm;
                if ($ip->is_ipv4()) {
                    $nm->[ 0 ]->bxor(Math::BigInt->from_hex('ffffffff'));
                }
                else {
                    $nm->[ 0 ]->bxor(Math::BigInt->from_hex('f' x 32));
                }
            }
            elsif ($arg_ref->{ ip } =~ m{(.*?)/(\d+)}) {
                my ($t, $cidr) = ($1, $2);
                $ip = IP($t);
                $cidr = $ip->is_ipv4() ? (32 - $cidr) : (128 - $cidr);
                $nm = Math::BigInt->new(2);
                $nm **= $cidr;
                $nm -= 1;
            }
            elsif ($arg_ref->{ cidr }) {
                $ip = IP($arg_ref->{ ip });
                my $cidr = $ip->is_ipv4() ? (32 - $arg_ref->{ cidr }) : (128 - $arg_ref->{ cidr });
                $nm = Math::BigInt->new(2);
                $nm **= $cidr;
                $nm -= 1;
            }
            else {
                $lower{ $this } = IP($arg_ref->{ ip });
                $upper{ $this } = IP($arg_ref->{ ip });
                return $self;
            }
            if ($ip->is_ipv4()) {
                $nm |= Math::BigInt->from_hex('0xffff00000000');
            }
            $lower{ $this } = IP($ip);
            $upper{ $this } = IP($ip | $nm);
            return $self;
        }
    }

}

sub as_string :STRINGIFY {
    my $self = shift;
    my $lower = $self->get_lower();
    my $upper = $self->get_upper();
    return "($lower .. $upper)";
}

sub as_cidr {
    my $self = shift;
    my $hr = $self->outer_bounds();
    return "$hr->{ base }" . '/' . "$hr->{ cidr }";
}

sub as_netmask {
    my $self = shift;
    my $hr = $self->outer_bounds();
    return "$hr->{ base }" . ' (' . "$hr->{ netmask }" . ')';
}

sub outer_bounds {
    my $self = shift;
    my $lower = $self->get_lower();
    my $upper = $self->get_upper();
    my @l = explode_ip($lower);
    my @u = explode_ip($upper);
    my @cidr = common_prefix(@l, @u);
    my $cidr = scalar @cidr;
    my @mask = prefix_mask(@l, @u);
    my $base = implode_ip(ip_pad_prefix(@cidr));
    my $nm   = implode_ip(ip_pad_prefix(@mask));
    my $x = Math::BigInt->new(2);
    $x **= (128 - $cidr);
    $x -= 1;
    my $hi = $base | $x;
    if ($lower->is_ipv4()) {
        $base = n32_to_ipv4( $base );
        $nm   = n32_to_ipv4( $nm   );
        $hi   = n32_to_ipv4( $hi   );
        $cidr -= 96;
    }
    return {
        base    => $base,
        cidr    => $cidr,
        netmask => $nm,
        highest => $hi,
    };
}

sub tight {
    my $self  = shift;
    my $lower = $self->get_lower();
    my $upper = $self->get_upper();
    my $hr    = $self->outer_bounds();
    my $rv    = Net::IPAddress::Util::Collection->new();
    if ($hr->{ highest } > $upper or $hr->{ base } < $lower) {
        my $mid = int(int($hr->{ base } + $hr->{ highest}) / 2);
        my $lo = __PACKAGE__->new({ lower => $lower,   upper => $mid   });
        my $hi = __PACKAGE__->new({ lower => $mid + 1, upper => $upper });
        push @$rv, @{$lo->tight()};
        push @$rv, @{$hi->tight()};
    }
    else {
        push @$rv, $self;
    }
    return $rv;
}

1;

__END__

=head1 NAME

Net::IPAddress::Util::Range - Representation of a range of IP addresses

=head1 SYNOPSIS

    use Net::IPAddress::Util::Range;

    my $x = '192.168.0.3';
    my $y = '192.168.0.123';

    my $range = Net::IPAddress::Util::Range->new({ lower => $x, upper => $y });

    print "$range\n"; # (192.168.0.3 .. 192.168.0.123)

    for (@{$range->tight()}) {
        print "$_\n";
    }

    my $w = '192.168.0.0/24';

    my $range = Net::IPAddress::Util::Range->new({ ip => $w });

    my $v = '192.168.0.0';

    my $range = Net::IPAddress::Util::Range->new({ ip => $v, cidr => 24 });

    my $z = '255.255.255.0';

    my $range = Net::IPAddress::Util::Range->new({ ip => $v, netmask => $z });

=head1 DESCRIPTION

=head1 CLASS METHODS

=head2 new

The constructor.

=head2 BUILD

Internal use only.

=head1 OBJECT METHODS

=head2 '""'

=head2 as_string

Objects stringify to a representation of their range.

=head2 as_cidr

Stringification for CIDR-style strings.

=head2 as_netmask

Stringification for Netmask-style strings.

=head2 outer_bounds

Return the bounds of the smallest subnet capable of completely containing
the addresses in this range. Note that this is not automatically the same
thing as "the subnet that matches this range", as a range may or may not be
aligned to legal subnet boundaries.

=head2 tight

Returns a collection of subnets that (between them) exactly match the
addresses in this range. The returned object is an Net::IPAddress::Util::Collection,
which can be treated as an array reference.

=head2 get_lower

=head2 set_lower

=head2 get_upper

=head2 set_upper

Get or set the lower or upper bounds of this range.

=cut


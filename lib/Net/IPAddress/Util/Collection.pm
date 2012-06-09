package Net::IPAddress::Util::Collection;

use 5.010;
use strict;

use Net::IPAddress::Util::Collection::Tie;

our $RADIX_THRESHOLD;

sub new {
    my $class    = ref($_[0]) ? ref(shift()) : shift;
    my @contents = @_;
    my @o;
    tie @o, 'Net::IPAddress::Util::Collection::Tie', \@contents;
    return bless \@o => $class;
}

sub sorted {
    my $self = shift;
    if (defined $RADIX_THRESHOLD and $RADIX_THRESHOLD < scalar @$self) {
        return $self->_radix_sort();
    }
    return $self->_native_sort();
}

sub _radix_sort {
    my $self = shift;
    my %lowdex;
    map { push @{$lowdex{$_->get_lower()->normal_form()}}, $_ } grep { $_ } @$self;
    my $lofrom = [keys %lowdex];
    my $loto;
    for (my $i = 30; $i >= 0; $i -= 2) {
        $loto = [];
        for my $card (@$lofrom) {
            push @{$loto->[hex(substr $card, $i, 2)]}, $card;
        }
        $lofrom = [map { @{ $_ || [] } } @$loto];
    }
    my @sorted;
    for my $bucket (@$lofrom) {
        my $bucket_size = scalar @{$lowdex{$bucket}};
        if ($bucket_size == 1) {
            push @sorted, $lowdex{$bucket}->[ 0 ];
        }
        elsif ($bucket_size > $RADIX_THRESHOLD) {
            push @sorted, map {
                $_->[ 1 ]
            }
            sort {
                $a->[ 0 ] <=> $b->[ 0 ]
            }
            map { [ $_->get_upper()->normal_form(), $_ ] }
            @{$lowdex{$bucket}};
        }
        else {
            my %hidex = map { $_->get_upper()->normal_form() => $_ } @{$lowdex{$bucket}};
            my $hifrom = [keys %hidex];
            my $hito;
            for (my $i = 30; $i >= 0; $i -= 2) {
                $hito = [];
                for my $card (@$hifrom) {
                    push @{$hito->[hex(substr $card, $i, 2)]}, $card;
                }
                $hifrom = [map { @{ $_ || [] } } @$hito];
            }
            push @sorted, map { $hidex{$_} } @$hifrom;
        }
    }
    return $self->new(@sorted);
}

sub _native_sort {
    my $self = shift;
    my @sorted = map {
        $_->[2]
    }
    sort {
        $a->[0] <=> $b->[0]
        || $a->[1] <=> $b->[1]
    }
    map {
        [ $_->get_lower(), $_->get_upper(), $_ ]
    } grep { $_ } @$self;
    return $self->new(@sorted);
}

sub compacted {
    my $self = shift;
    my @sorted = @{$self->sorted()};
    my @compacted;
    my $elem;
    while ($elem = shift @sorted) {
        if (scalar @sorted and $elem->get_upper() >= $sorted[0]->get_lower() - 1) {
            $elem->set_upper($sorted[0]->get_upper());
            shift @sorted;
            redo;
        }
        else {
            push @compacted, $elem;
        }
    }
    return $self->new(@compacted);
}

sub tight {
    my $self = shift;
    my @tight;
    map { push @tight, @{$_->tight()} } @{$self->compacted()};
    return $self->new(@tight);
}

sub as_cidrs {
    my $self = shift;
    return map { $_->as_cidr() } @$self;
}

sub as_netmasks {
    my $self = shift;
    return map { $_->as_netmask() } @$self;
}

sub as_ranges {
    my $self = shift;
    return map { $_->as_string() } @$self;
}

1;

__END__

=head1 NAME

Net::IPAddress::Util::Collection - A collection of Net::IPAddress::Util::Range objects

=head1 SYNOPSIS

    use Net::IPAddress::Util::Collection;

    my $collection = Net::IPAddress::Util::Collection->new();

    while (<>) {
        last unless $_;
        push @$collection, $_;
    }

    print join ', ', $collection->tight()->as_ranges();

=head1 DESCRIPTION

=head1 CLASS METHODS

=head2 new

Create a new object.

=head1 OBJECT METHODS

=head2 sorted

Return a clone of this object, sorted ascendingly by IP address.

=head2 compacted

Return a clone of this object, sorted ascendingly by IP address, with
adjacent ranges combined together.

=head2 tight

Return a clone of this object, compacted and split into tight ranges. See
Net::IPAddress::Util::Range for an explanation of "tight" in this context.

=head2 as_ranges

Stringification for (x .. y) style ranges.

=head2 as_cidrs

Stringification for CIDR-style strings.

=head2 as_netmasks

Stringification for Netmask-style strings.

=head1 GLOBAL VARIABLES

=head2 $Net::IPAddress::Util::Collection::RADIX_THRESHOLD

If set to any defined value (including zero), collections with more than
$RADIX_THRESHOLD elements will be sorted using the radix sort algorithm,
which can be faster than Perl's native sort for large data sets. The default
value is C<undef()>.

=cut


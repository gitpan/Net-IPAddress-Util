package Net::IPAddress::Util::Collection::Tie;

use 5.010;
use strict;

use Carp qw( confess );
use Class::Std;
use Net::IPAddress::Util::Range;

my %contents :ATTR( :name<contents> :default<[]> );

sub TIEARRAY {
    my ($class, $contents) = @_;
    $contents = [] unless defined $contents;
    @{$contents} = map { _checktype($_) } @{$contents};
    my $self = $class->new({ contents => $contents });
}

sub FETCH {
    my ($self, $i) = @_;
    return $self->get_contents()->[ $i ];
}

sub STORE {
    my ($self, $i, $v) = @_;
    $self->get_contents()->[ $i ] = _checktype($v);
    return $v;
}

sub FETCHSIZE {
    my ($self) = @_;
    return scalar @{$self->get_contents()};
}

sub EXISTS {
    my ($self, $i) = @_;
    return exists $self->get_contents()->[ $i ];
}

sub DELETE {
    my ($self, $i) = @_;
    return delete $self->get_contents()->[ $i ];
}

sub CLEAR {
    my ($self) = @_;
    $self->set_contents([]);
    return $self->get_contents();
}

sub PUSH {
    my ($self, @l) = @_;
    push @{$self->get_contents()}, map { _checktype($_) } @l;
}

sub POP {
    my ($self) = @_;
    return pop @{$self->get_contents()};
}

sub UNSHIFT {
    my ($self, @l) = @_;
    unshift @{$self->get_contents()}, map { _checktype($_) } @l;
}

sub SHIFT {
    my ($self) = @_;
    return shift @{$self->get_contents()};
}

sub SPLICE {
    my ($self, $offset, $length, @l) = @_;
    $offset = 0 unless defined $offset;
    $length = $self->FETCHSIZE() - $offset unless defined $length;
    return splice @{$self->get_contents()}, $offset, $length, map { _checktype($_) } @l;
}

sub _checktype {
    my ($v) = @_;
    return $v if ref $v eq 'Net::IPAddress::Util::Range';
    if (ref $v eq 'HASH') {
        $v = Net::IPAddress::Util::Range->new($v);
    }
    if (ref $v eq 'Net::IPAddress::Util') {
        $v = Net::IPAddress::Util::Range->new({ ip => $v });
    }
    if (!defined $v or ref $v ne 'Net::IPAddress::Util::Range') {
        my $disp = defined $v ? ref $v ? ref $v : 'scalar' : 'undef()';
        confess("Invalid data type ($disp)");
    }
    return $v;
}

1;

__END__

=head1 NAME

Net::IPAddress::Util::Collection::Tie - These aren't the droids you're looking for

=cut


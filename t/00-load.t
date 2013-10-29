#!perl -T

use Test::More tests => 5;

BEGIN {
    use_ok( 'Net::IPAddress::Util' );
    use_ok( 'Net::IPAddress::Util::Range' );
    use_ok( 'Net::IPAddress::Util::Collection' );
    use_ok( 'Net::IPAddress::Util::Collection::Tie' );
    use_ok( 'mop' );
}

diag( "Testing Net::IPAddress::Util $Net::IPAddress::Util::VERSION, Perl $], mop $mop::VERSION, $^X" );

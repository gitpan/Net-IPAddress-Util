#! perl -T

use strict;
use warnings;

use Net::IPAddress::Util try => 'GMP';
use Test::More tests => 1;

diag( 'Tried GMP. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });
ok(1, 'Tried GMP. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });


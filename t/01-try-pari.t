#! perl -T

use strict;
use warnings;

use Net::IPAddress::Util try => 'Pari';
use Test::More tests => 1;

diag( 'Tried Pari. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });
ok(1, 'Tried Pari. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });


#! perl -T

use strict;
use warnings;

use Net::IPAddress::Util try => 'Calc';
use Test::More tests => 1;

diag( 'Tried Calc. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });
ok(1, 'Tried Calc. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });


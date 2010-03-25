#! perl -T

use strict;
use warnings;

use Net::IPAddress::Util try => 'FastCalc';
use Test::More tests => 1;

diag( 'Tried FastCalc. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });
ok(1, 'Tried FastCalc. Got ' . Net::IPAddress::Util->config()->{ lib } . ' ' . Net::IPAddress::Util->config()->{ lib_version });


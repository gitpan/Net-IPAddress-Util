use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Net::IPAddress::Util',
    AUTHOR              => q{Paul Bennett <paul.w.bennett@gmail.com>},
    VERSION_FROM        => 'lib/Net/IPAddress/Util.pm',
    ABSTRACT_FROM       => 'lib/Net/IPAddress/Util.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'   => '0',
        'Class::Std'   => '0.011',
        'Regexp::IPv6' => '0.03',
        'Math::BigInt' => '1.997',
    },
    MIN_PERL_VERSION => '5.010000',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Net-IPAddress-Util-*' },
);

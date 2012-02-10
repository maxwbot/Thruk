use strict;
use warnings;
use Test::More tests => 13;
use Data::Dumper;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# check module
SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::mobile';
};

###########################################################
# initialize object config
TestUtils::test_page(
    'url'      => '/thruk/cgi-bin/mobile.cgi',
    'follow'   => 1,
    'unlike'   => [ 'internal server error', 'HASH', 'ARRAY' ],
    'like'     => 'Mobile Thruk',
);

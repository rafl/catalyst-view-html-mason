use strict;
use warnings;
use Test::More;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN {
  my @required = qw/ HTML::Mason::Request::Catalyst /;
  for my $dep ( @required ) {
    eval "require $dep";
    if ( $@ ) { plan skip_all => "Needs $dep"; exit }
  }
}

use Catalyst::Test 'TestAppCustomRequest';

is(get('/'), "tiger\n" x 2, 'Basic rendering' );
is(get('/no_traits'), "tiger\n" x 2, 'Basic rendering' );

is(get('/traits'), "1 + 2 = 3", 'Traits' );


done_testing;

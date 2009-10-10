use strict;
use warnings;
use Test::More;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

is(get('/'), "tiger\n" x 2, 'Basic rendering' );

is(get('/path_class'), "tiger\n" x 2, 'Path::Class objects as comp_root' );

done_testing;

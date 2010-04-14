use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN {
  my @required = qw/ Catalyst::Plugin::Unicode::Encoding /;
  for my $dep ( @required ) {
    eval "require $dep";
    if ( $@ ) { plan skip_all => "Needs $dep"; exit }
  }
}


{
  package without_encoding;

  use Test::More;
  use Catalyst::Test 'TestApp';

  my $utf8 = get('/enc_utf8');
  isnt $utf8, 'Er flüsterte: Ich darf auf den großen Platz fahren.',
    'Expected wrong byte string without any encoding';
}

{
  package with_encoding;

  use Test::More;
  use Catalyst::Test 'TestAppEnc';

  my $utf8 = get('/enc_utf8');
  is $utf8, 'Er flüsterte: Ich darf auf den großen Platz fahren.',
    'Correct byte string with encoding and Unicode::Encoding plugin';

  my $meths = get('/enc_methods');
  $meths =~ s/[\s\t\n\r]//g;
  is $meths, ( 'Äffchen' x 8 ),
    'Correct byte string from method calls';

  note( TestAppEnc->view->fetch_comp('enc/methods')->object_file );
}

done_testing;

package TestAppCustomRequest;

use Moose;
extends 'Catalyst';

__PACKAGE__->config( default_view => 'Mason' );
__PACKAGE__->setup(
#  qw/-Debug/
);

1;

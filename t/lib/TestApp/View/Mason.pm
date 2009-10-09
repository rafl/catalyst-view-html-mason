package TestApp::View::Mason;

use Moose;
use namespace::autoclean;

extends 'Catalyst::View::HTML::Mason';

__PACKAGE__->config(
    interp_args => [
        comp_root => '' . TestApp->path_to('root'),
    ],
);

__PACKAGE__->meta->make_immutable;

1;

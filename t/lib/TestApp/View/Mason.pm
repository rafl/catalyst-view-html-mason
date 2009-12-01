package TestApp::View::Mason;

use Moose;
use namespace::autoclean;

extends 'Catalyst::View::HTML::Mason';

__PACKAGE__->config(
    globals => [
        '$affe',
        ['$ctx' => sub { $_[1] }],
    ],
);

__PACKAGE__->meta->make_immutable;

1;

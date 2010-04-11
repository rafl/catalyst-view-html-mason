package TestAppEnc::View::Mason;

use Moose;
use namespace::autoclean;

extends 'Catalyst::View::HTML::Mason';

__PACKAGE__->config(
    globals => [
        '$affe',
        ['$ctx' => sub { $_[1] }],
    ],
    interp_args => {
        comp_root => TestAppEnc->path_to('root')->stringify,
    },
    encoding => 'utf8',
);

__PACKAGE__->meta->make_immutable;

1;

package TestApp::Controller::Root;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace => '',
);

sub index : Path Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash(affe => 'tiger');
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;

1;

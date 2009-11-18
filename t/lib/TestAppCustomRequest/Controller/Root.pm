package TestAppCustomRequest::Controller::Root;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace => '',
);

sub index : Path Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash( affe => 'tiger' );
}

sub traits : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash( two => 2 );
    $ctx->forward( 'View::Traits' );
};

sub no_traits : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash( affe => 'tiger', template => 'index' );
    $ctx->forward( 'View::Traits' );
};

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;

1;

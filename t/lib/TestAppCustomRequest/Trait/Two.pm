package TestAppCustomRequest::Trait::Two;

use Moose::Role;
use namespace::autoclean;

requires 'catalyst_ctx';

sub two {
  my $self = shift;
  $self->catalyst_ctx->stash->{two};
}

no Moose::Role;

1;

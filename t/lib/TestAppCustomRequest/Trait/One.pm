package TestAppCustomRequest::Trait::One;

use Moose::Role;
use namespace::autoclean;

sub one { 1 }

no Moose::Role;

1;

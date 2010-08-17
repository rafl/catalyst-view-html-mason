package Catalyst::Helper::View::HTML::Mason;

use strict;
use warnings;

our $VERSION = '0.01';

=head1 NAME

Catalyst::Helper::View::HTML::Mason - Helper for
L<Catalyst::View::HTML::Mason> views

=head1 SYNOPSIS

    script/create.pl view Mason HTML::Mason

=head2 METHODS

=head3 mk_compclass

=cut

sub mk_compclass {
    my ($self, $helper) = @_;
    my $file = $helper->{file};
    $helper->render_file('compclass', $file);
}

=head1 SEE ALSO

L<Catalyst::View::HTML::Mason>, L<Catalyst::Manual>,
L<Catalyst::Test>, L<Catalyst::Request>, L<Catalyst::Response>,
L<Catalyst::Helper>

=head1 AUTHOR

Robert Buels <rbuels@cpan.org>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;

__DATA__

__compclass__
package [% class %];
use Moose;
extends 'Catalyst::View::HTML::Mason';

## uncomment below to pass default configuration options to this view
# __PACKAGE__->config( );

=head1 NAME

[% class %] - Mason View Component for [% app %]

=head1 DESCRIPTION

Mason View Component for [% app %]

=head1 SEE ALSO

L<[% app %]>, L<Catalyst::View::HTML::Mason>, L<HTML::Mason>

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;

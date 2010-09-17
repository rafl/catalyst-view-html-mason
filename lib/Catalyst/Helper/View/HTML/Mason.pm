package Catalyst::Helper::View::HTML::Mason;
# ABSTRACT: Helper for L<Catalyst::View::HTML::Mason> views

use strict;
use warnings;

=head1 SYNOPSIS

    script/create.pl view Mason HTML::Mason

=method mk_compclass

=cut

sub mk_compclass {
    my ($self, $helper) = @_;
    my $file = $helper->{file};
    (my $template = do { local $/; <DATA> }) =~ s/^\s\s//g;
    $helper->render_file_contents($template, $file);
}

=head1 SEE ALSO

L<Catalyst::View::HTML::Mason>, L<Catalyst::Manual>,
L<Catalyst::Test>, L<Catalyst::Request>, L<Catalyst::Response>,
L<Catalyst::Helper>

=cut

1;

__END__
__DATA__
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

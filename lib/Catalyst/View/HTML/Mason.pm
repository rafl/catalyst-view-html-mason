package Catalyst::View::HTML::Mason;
# ABSTRACT: HTML::Mason rendering for Catalyst

use Moose;
use Try::Tiny;
use MooseX::Types::Moose
    qw/ArrayRef HashRef ClassName Str Bool Object CodeRef/;

use MooseX::Types::Structured qw/Tuple/;
use Encode::Encoding;
use Data::Visitor::Callback;

use namespace::autoclean;

extends 'Catalyst::View';
with 'Catalyst::Component::ApplicationAttribute';

=head1 SYNOPSIS

    package MyApp::View::Mason;

    use Moose;
    use namespace::autoclean;

    extends 'Catalyst::View::HTML::Mason';

    __PACKAGE__->config(
        interp_args => {
            comp_root => MyApp->path_to('root'),
        },
    );

    1;

=head1 DESCRIPTION

This module provides rendering of HTML::Mason templates for Catalyst
applications.

It's basically a rewrite of L<Catalyst::View::Mason|Catalyst::View::Mason>,
which became increasingly hard to maintain over time, while keeping backward
compatibility.

=attr interp

The mason interpreter instance responsible for rendering templates.

=cut

has interp => (
    is      => 'ro',
    isa     => Object,
    lazy    => 1,
    builder => '_build_interp',
);

=attr interp_class

The class the C<interp> instance is constructed from. Defaults to
C<HTML::Mason::Interp>.

=cut

{
    use Moose::Util::TypeConstraints;

    my $tc = subtype as ClassName;
    coerce $tc, from Str, via { Class::MOP::load_class($_); $_ };

    has interp_class => (
        is      => 'ro',
        isa     => $tc,
        coerce  => 1,
        builder => '_build_interp_class',
    );

=attr interp_args

Arguments to be passed to the construction of C<interp>. Defaults to an empty
hash reference.

=cut

    has interp_args => (
        is      => 'ro',
        isa     => HashRef,
        default => sub { +{} },
    );


=attr request_class

The class to use as a custom request class for Mason. In conjunction
with C<request_class_roles> and L<HTML::Mason::Request::Catalyst> this
can be used as shortcut for manually constructing L<HTML::Mason::Request>
subclasses and avoid common pitfalls when moosifing the request.

=cut

    has request_class => (
        is        => 'ro',
        isa       => $tc,
        coerce    => 1,
        predicate => 'has_custom_request_class'
    );

=attr request_class_roles

Array ref of roles that are automattically applied to the request class

=cut

    has request_class_roles => (
        is      => 'ro',
        isa     => ArrayRef,
        predicate => 'has_request_class_roles'
    );

}

=attr template_extension

File extension to be appended to every component file. By default it's only
appended if no explicit component file has been provided in
C<< $ctx->stash->{template} >>.

=cut

has template_extension => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

=attr always_append_template_extension

If this is set to a true value, C<template_extension> will also be appended to
component paths provided in C<< $ctx->stash->{template} >>.

=cut

has always_append_template_extension => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

=attr encoding

FIXME

=cut

{
    my $tc = subtype as 'Encode::Encoding';
    coerce $tc, from Str, via { Encode::find_encoding($_) };

    has encoding => (
        is        => 'ro',
        isa       => $tc,
        coerce    => 1,
        predicate => 'has_encoding',
    );
}

=attr globals

FIXME

=cut

{
    my $glob_spec = subtype as Tuple[Str,CodeRef];
    coerce $glob_spec, from Str, via {
        my ($type, $var) = split q//, $_, 2;
        my $fn = {
            '$' => sub { $_[0] },
            '@' => sub {
                return unless defined $_[0];
                ref $_[0] eq 'ARRAY'
                    ? @{ $_[0] }
                    : !ref $_[0]
                        ? $_[0]
                        : ();
            },
            '%' => sub {
                return unless defined $_[0];
                ref $_[0] eq 'HASH'
                    ? %{ $_[0] }
                    : ();
            },
        }->{ $type };
        [$_ => sub { $fn->( $_[1]->stash->{$var} ) }];
    };

    my $tc = subtype as ArrayRef[$glob_spec];
    coerce $tc, from ArrayRef, via { [map { $glob_spec->coerce($_) } @$_ ]};

    has globals => (
        is      => 'ro',
        isa     => $tc,
        coerce  => 1,
        builder => '_build_globals',
    );
}

around BUILDARGS => sub {
  my $orig = shift;
  my $class = shift;
  my %p = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;

  return $class->$orig( %p ) unless exists $p{interp_args};

  die "Can't specify request_class in both main config and interp_args"
    if exists $p{request_class} and exists $p{interp_args}{request_class};

  return $class->$orig( %p );
};


sub BUILD {
    my ($self) = @_;
    $self->interp;
}

sub _build_globals { [] }

sub _build_request_class { 'HTML::Mason::Request' }

sub _build_interp_class { 'HTML::Mason::Interp' }

sub _create_request_class_impl {
    my ($self) = @_;

    if ( not $self->has_custom_request_class ) {
        $self->_application->log->warn(
            "Can't apply roles to the default request class"
        ) if $self->has_request_class_roles;

        return 'HTML::Mason::Request';
    }

    if ( $self->has_request_class_roles ) {
        my $meta = Moose::Meta::Class->create_anon_class(
            superclasses => [ $self->request_class ],
            roles        => $self->request_class_roles,
        );

        # make anon class persistent and immutable
        $meta->add_method( meta => sub{ $meta });
        $meta->make_immutable;

        return $meta->name;
    }

    if ( my $meta = Class::MOP::class_of( $self->request_class )) {
        $self->_application->log->warn(
            $meta->name . " should be immutable or rendering might break"
        ) if $meta->is_mutable;
    }

    return $self->request_class;
}

sub _build_interp {
    my ($self) = @_;

    my %args = %{ $self->interp_args };
    if ($self->has_encoding) {
        my $old_func = delete $args{postprocess_text};
        $args{postprocess_text} = sub {
            $old_func->($_[0]) if $old_func;
            ${ $_[0] } = $self->encoding->decode(${ $_[0] });
        };
    }

    $args{comp_root} ||= $self->_application->path_to( 'root' );

    $args{allow_globals} ||= [];
    unshift @{ $args{allow_globals}}, map { $_->[0] } @{ $self->globals };

    $args{request_class} ||= $self->_create_request_class_impl;

    $args{in_package} ||= sprintf '%s::Commands', do {
        if (my $meta = Class::MOP::class_of($self)) {
            $meta->name;
        } else {
            ref $self;
        }
    };

    my $v = Data::Visitor::Callback->new(
        'Path::Class::Entity' => sub { blessed $_ ? $_->stringify : $_ },
    );

    return $self->interp_class->new( $v->visit(%args) );
}

sub render {
    my ($self, $ctx, $comp, $args) = @_;
    my $output = '';

    for (@{ $self->globals }) {
        my ($decl, @values) = ($_->[0] => $_->[1]->($self, $ctx));
        if (@values) {
            $self->interp->set_global($decl, @values);
        } else {
            # HTML::Mason::Interp->set_global would crash on empty lists
            $self->_unset_interp_global($decl);
        }
    }

    try {
        my %req_args = (
          comp => $self->fetch_comp($comp),
          args => [$args ? %{ $args } : %{ $ctx->stash }],
          out_method => \$output,
        );

        if ( my $meta = eval{ Class::MOP::class_of( $self->request_class )}) {
          # add context to args if the standard interface is supported
          $req_args{catalyst_ctx} = $ctx
            if $req_meta->does_role( 'MasonX::RequestContext::Catalyst' );
        }

        $self->interp->make_request( %req_args )->exec;
    }
    catch {
        confess $_;
    };

    return $output;
}

sub process {
    my ($self, $ctx) = @_;
    my $comp   = $self->_get_component($ctx);
    my $output = $self->render($ctx, $comp);
    $ctx->response->body($output);
}

sub fetch_comp {
    my ($self, $comp) = @_;
    my $method;

    $comp = $comp->stringify
        if blessed $comp && $comp->isa( 'Path::Class' );

    return $comp
        if blessed $comp;

    ($comp, $method) = @{ $comp }
        if ref $comp && ref $comp eq 'ARRAY';

    $comp = "/$comp"
        unless $comp =~ m{^/};

    my $component = $self->interp->load($comp);
    confess "Can't find component for path $comp"
        unless $component;

    $component = $component->methods($method)
        if defined $method;

    return $component;
}


sub _get_component {
    my ($self, $ctx) = @_;

    my $comp = $ctx->stash->{template};
    my $extension = $self->template_extension;

    if (defined $comp) {
        $comp .= $extension
            if !ref $comp && $self->always_append_template_extension;

        return $comp;
    }

    return $ctx->action->reverse . $extension;
}

sub _unset_interp_global {
    my ($self, $decl) = @_;
    my ($prefix, $name) = split q//, $decl, 2;
    my $package = $self->interp->compiler->in_package;
    my $varname = sprintf "%s::%s", $package, $name;

    no strict 'refs';
    if    ($prefix eq '$') { $$varname = undef }
    elsif ($prefix eq '@') { @$varname = () }
    else                   { %$varname = () }
}

__PACKAGE__->meta->make_immutable;

1;

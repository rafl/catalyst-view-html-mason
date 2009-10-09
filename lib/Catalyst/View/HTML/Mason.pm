package Catalyst::View::HTML::Mason;

use Moose;
use Try::Tiny;
use Moose::Autobox;
use MooseX::Types::Moose qw/ArrayRef ClassName Str Bool Object/;
use namespace::autoclean;

extends 'Catalyst::View';

has interp => (
    is      => 'ro',
    isa     => Object,
    lazy    => 1,
    builder => '_build_interp',
);

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
}

has interp_args => (
    is  => 'ro',
    isa => ArrayRef,
);

has template_extension => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has always_append_template_extension => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

{
    my $tc = subtype as ArrayRef[ArrayRef];
    coerce $tc, from ArrayRef, via {
        [map {
            ref $_
                ? $_
                : do { my $var = substr $_, 1; [$_ => sub { $_[1]->stash->{$var} }] };
        } @{ $_ }]
    };

    has globals => (
        is      => 'ro',
        isa     => $tc,
        coerce  => 1,
        builder => '_build_globals',
    );
}

sub BUILD {
    my ($self) = @_;
    $self->interp;
}

sub _build_globals { [] }

sub _build_interp_class { 'HTML::Mason::Interp' }

sub _build_interp {
    my ($self) = @_;
    return $self->interp_class->new(
        @{ $self->interp_args || [] },
        allow_globals => $self->globals->map(sub { $_->[0] }),
    );
}

sub render {
    my ($self, $ctx, $comp, $args) = @_;
    my $output = '';

    $self->interp->set_global(
        $_->[0] => $_->[1]->($self, $ctx),
    ) for @{ $self->globals };

    try {
        $self->interp->make_request(
            comp => $self->load_component($comp),
            args => [$args ? %{ $args } : %{ $ctx->stash }],
            out_method => \$output,
        )->exec;
    }
    catch {
        confess $_;
    };

    return $output;
}

sub process {
    my ($self, $ctx) = @_;

    my $comp   = $self->get_component($ctx);
    my $output = $self->render($ctx, $comp);

    $ctx->response->body($output);
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

sub load_component {
    my ($self, $comp) = @_;
    my $method;

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

__PACKAGE__->meta->make_immutable;

1;

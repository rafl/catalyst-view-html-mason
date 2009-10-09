package Catalyst::View::HTML::Mason;

use Moose;
use Try::Tiny;
use MooseX::Types::Moose qw/ArrayRef ClassName Str Bool/;
use namespace::autoclean;

extends 'Catalyst::View';

has interp => (
    is      => 'ro',
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

sub _build_interp_class { 'HTML::Mason::Interp' }

sub _build_interp {
    my ($self) = @_;
    return $self->interp_class->new(
        @{ $self->interp_args || [] },
    );
}

sub render {
    my ($self, $ctx, $comp, $args) = @_;
    my $output = '';

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

sub get_component {
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

package Catalyst::View::HTML::Mason;

use Moose;
use Try::Tiny;
use MooseX::Types::Moose
    qw/ArrayRef HashRef ClassName Str Bool Object CodeRef/;
use MooseX::Types::Structured qw/Tuple/;
use Encode::Encoding;
use Data::Visitor::Callback;

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
    is      => 'ro',
    isa     => HashRef,
    default => sub{ +{} },
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

  my $tc = subtype as 'Encode::Encoding';
  coerce $tc, from Str, via { Encode::find_encoding( $_ ) };

  has encoding => (
    is     => 'ro',
    isa    => $tc,
    coerce => 1,
  );

}

{
    my $glob_spec = subtype as Tuple[Str,CodeRef];
    coerce $glob_spec, from Str, via {
        my ( $type, $var ) = split( qr//, $_, 2 );
        my $fn   = {
           '$' => sub{ $_[0] },
           '@' => sub{
               return unless defined $_[0];
               ref $_[0] eq 'ARRAY'? @{$_[0]}: !ref $_[0]? $_[0]: ();
           },
           '%' => sub{
               return unless defined $_[0];
               ref $_[0] eq 'HASH' ? %{$_[0]} : ();
           },
        }->{ $type };
        [ $_ => sub{ $fn->( $_[1]->stash->{ $var })} ];
    };

    my $tc = subtype as ArrayRef[ $glob_spec ];
    coerce $tc, from ArrayRef, via{ [ map{ $glob_spec->coerce( $_ ) } @$_ ]};

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

    my %args = %{ $self->interp_args };
    if ( my $enc = $self->encoding ) {
        my $old_func = delete $args{ postprocess_text };
        $args{ postprocess_text } = sub{
            $old_func->( $_[0] ) if $old_func;
            ${$_[0]} = $enc->decode( ${$_[0]} );
        };
    }

    $args{allow_globals} ||= [];
    unshift @{ $args{allow_globals}}, map{ $_->[0] } @{ $self->globals };

    $args{in_package} ||= sprintf '%s::Commands', do{
        if ( my $meta = Class::MOP::class_of( $self )) {
            $meta->name;
        } else {
            ref $self;
        }
    } ;

    my $v = Data::Visitor::Callback->new(
        'Path::Class::Entity' => sub{ blessed $_ ? $_->stringify : $_ },
    );

    return $self->interp_class->new( $v->visit( %args ) );
}

sub render {
    my ($self, $ctx, $comp, $args) = @_;
    my $output = '';

    for ( @{ $self->globals } ) {
        my ( $decl, @values ) = ( $_->[0] => $_->[1]->($self, $ctx));
        if ( @values ) {
            $self->interp->set_global( $decl, @values );
        } else {
            # HTML::Mason::Interp->set_global would crash on empty lists
            $self->_unset_interp_global( $decl );
        }
    }

    try {
        $self->interp->make_request(
            comp => $self->fetch_comp($comp),
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

    my $comp   = $self->_get_component($ctx);
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

sub _unset_interp_global {
    my ( $self, $decl ) = @_;
    my ( $prefix, $name ) = split( qr//, $decl, 2 );
    my $package = $self->interp->compiler->in_package;
    my $varname = sprintf( "%s::%s", $package, $name );

    no strict 'refs';
    if    ($prefix eq '$') { $$varname = undef }
    elsif ($prefix eq '@') { @$varname = () }
    else                   { %$varname = () }
}

__PACKAGE__->meta->make_immutable;

1;

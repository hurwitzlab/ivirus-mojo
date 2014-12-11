package IVirus::Controller::Welcome;

use Data::Dump 'dump';
use Mojo::Base 'Mojolicious::Controller';

# ----------------------------------------------------------------------
sub index {
    my $self = shift;

    my @routes = sort (
        grep { !/\/(admin|feedback)/ }
        grep { /\S+/ }
        map  { $_->to_string   }
        grep { $_->is_endpoint }
        @{ $self->app->routes->children }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => \@routes );
        },

        html => sub {
            $self->layout('default');
            $self->render();
        },

        txt => sub {
            $self->render( text => dump(\@routes) );
        },
    );
}

# ----------------------------------------------------------------------
sub carousel {
    my $self = shift;
    $self->layout('default');
    $self->render();
}

1;

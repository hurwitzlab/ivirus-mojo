package IVirus::Controller::ProjectPage;

use strict;
use IVirus::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                view => {
                    params => {
                        project_page_id => {
                            type     => 'int',
                            desc     => 'the project page id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a project page',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self  = shift;
    my $pp_id = $self->param('project_page_id');
    my $db    = IVirus::DB->new;
    my $Page  = $db->schema->resultset('ProjectPage')->find($pp_id);

    if (!$Page) {
        return $self->reply->exception("Bad project page id ($pp_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => { $Page->get_inflated_columns() } );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title => sprintf("Project Page: %s", $Page->title),
                page  => $Page,
            );
        },

        txt => sub {
            $self->render( text => dump({$Page->get_inflated_columns()}) );
        },
    );
}

1;

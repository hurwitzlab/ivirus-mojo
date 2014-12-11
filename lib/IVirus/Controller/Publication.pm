package IVirus::Controller::Publication;

use IVirus::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';
use DBI;

# ----------------------------------------------------------------------
sub info {
    my $self = shift;

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                list => {
                    results => 'a list of publications',
                },

                view => {
                    params => {
                        publication_id => {
                            type     => 'int',
                            desc     => 'the publication id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a publication',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = IVirus::DB->new->dbh;
    my $pubs = $dbh->selectall_arrayref(
        q[
            select publication_id, pub_code, pub_date, journal, 
                   author, title, pubmed_id
            from   publication
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $pubs );
        },

        html => sub {
            $self->layout('default');

            $self->render( pubs => $pubs, title => 'Publications' );
        },

        txt => sub {
            $self->render( text => dump($pubs) );
        },

        tab => sub {
            my $text = '';

            if (@$pubs) {
                my @flds = sort keys %{ $pubs->[0] };
                my @data = (join "\t", @flds);
                for my $pub (@$pubs) {
                    push @data, join "\t", map { $pub->{$_} // '' } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self   = shift;
    my $pub_id = $self->param('publication_id');
    my $dbh    = IVirus::DB->new->dbh;

    my $sth = $dbh->prepare('select * from publication where publication_id=?');

    $sth->execute($pub_id);

    my $pub = $sth->fetchrow_hashref;

    if (!$pub) {
        return $self->reply->exception("Bad publication id ($pub_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $pub );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                pub   => $pub,
                title => 
                    sprintf('Publication: %s', $pub->{'title'} || 'Untitled'),
            );
        },

        txt => sub {
            $self->render( text => dump($pub) );
        },
    );
}

1;

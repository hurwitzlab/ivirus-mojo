package IVirus::Controller::Pubchase;

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
                    results => 'the articles recommended by PubChase.com',
                }
            });
        }
    );
}


# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = IVirus::DB->new->dbh;
    my $last = $dbh->selectrow_array(
        'select rec_date from pubchase_rec order by rec_date desc limit 1'
    );
    my $pubs = $dbh->selectall_arrayref(
        q[
            select   pubchase_id, article_id, title, journal_title, 
                     doi, authors, article_date, created_on, url
            from     pubchase
            order by article_date desc, title
        ],
        { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render(json => { last_update => $last, pubs => $pubs });
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                pubs        => $pubs,
                title       => 'Pubchase Recommendations',
                last_update => $last,
            );
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

1;

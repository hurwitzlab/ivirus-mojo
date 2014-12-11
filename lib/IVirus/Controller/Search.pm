package IVirus::Controller::Search;

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
                search => {
                    params => {
                        query => {
                            type => 'str',
                            desc  => 'a string to search',
                            required => 'true',
                        }
                    },
                    results => 'a list of matching documents',
                }
            });
        },
    );

}

# ----------------------------------------------------------------------
sub results {
    my $self  = shift;
    my $req   = $self->req;
    my $query = $req->param('query') || '';
    my $dbh   = IVirus::DB->new->dbh;

    my @results;
    my %types;
    if ($query) {
        my $sql = sprintf(
            "select * from search where match (search_text) against (%s)",
            $dbh->quote($query)
        );

        if (my $type = $req->param('type')) {
            $sql .= sprintf(" and table_name=%s", $dbh->quote($type));
        }

        my $data = $dbh->selectall_arrayref($sql, { Columns => {} });

        for my $r (@$data) {
            $types{ $r->{'table_name'} }++;

            my $sql = sprintf('select * from %s where %s=?', 
                $r->{'table_name'}, $r->{'table_name'} . '_id'
            );

            my $sth = $dbh->prepare($sql);
            $sth->execute($r->{'primary_key'});
            $r->{'object'} = $sth->fetchrow_hashref();
            $r->{'url'}    = join '/', 
                '', $r->{'table_name'}, 'view', $r->{'primary_key'};

            push @results, $r;
        }
    }

    $self->respond_to(
        json => sub {
            $self->render(json => { 
                query   => $query, 
                results => \@results,
                types   => \%types,
            });
        },

        html => sub {
            $self->layout('default');

            $self->render(
                title   => "Search results for $query",
                results => \@results,
                query   => $query,
                types   => \%types
            );
        },

        txt => sub {
            $self->render( text => dump(\@results) );
        },

        tab => sub {
            my $text = '';

            if (@results) {
                my @flds = sort keys %{ $results[0] };
                my @data = (join "\t", @flds);
                for my $res (@results) {
                    push @data, join "\t", 
                        map { ref $res->{$_} ? '-' : $res->{$_} // '' } 
                        @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

1;

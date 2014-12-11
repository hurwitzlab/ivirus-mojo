package IVirus::Controller::Sample;

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
                    params => {
                        project_id => {
                            type => 'int',
                            desc => 'value of the project id to which the '
                                 .  'samples belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of samples',
                },

                view => {
                    params => {
                        sample_id => {
                            type => 'int',
                            desc => 'the sample id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a sample',
                }
            });
        }
    );
}

# ----------------------------------------------------------------------
sub list {
    my $self = shift;
    my $dbh  = IVirus::DB->new->dbh;
    my $sql  = q[
        select s.sample_id, s.sample_name, s.sample_type,
               s.reads_file, s.annotations_file, s.peptides_file, 
               s.contigs_file, s.cds_file,
               s.phylum, s.class, s.family, s.genus, s.species, 
               s.strain, s.clonal, s.axenic, s.pcr_amp, s.pi,
               s.latitude, s.longitude,
               p.project_id, p.project_name
        from   sample s, project p
        where  s.project_id=p.project_id
    ];

    if (my $project_id = $self->req->param('project_id')) {
        $sql .= sprintf('and s.project_id=%s', $dbh->quote($project_id));
    }

    my $samples = $dbh->selectall_arrayref($sql, { Columns => {} });

    $self->respond_to(
        json => sub {
            $self->render( json => $samples );
        },

        html => sub {
            $self->layout('default');
            $self->render( title => 'Samples', samples => $samples );
        },

        txt => sub {
            $self->render( text => dump($samples) );
        },

        tab => sub {
            my $text = '';

            if (@$samples) {
                my @flds = sort keys %{ $samples->[0] };
                my @data = (join "\t", @flds);
                for my $sample (@$samples) {
                    push @data, join "\t", map { $sample->{$_} // '' } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self      = shift;
    my $sample_id = $self->param('sample_id') or die 'No sample id';
    my $dbh       = IVirus::DB->new->dbh;

    if ($sample_id =~ /^\D/) {
        for my $fld (qw[ sample_name sample_acc ]) {
            my $sql = "select sample_id from sample where $fld=?";
            if (my $id = $dbh->selectrow_array($sql, {}, $sample_id)) {
                $sample_id = $id;
                last;    
            }
        }
    }

    my $sth = $dbh->prepare(
        q[
            select s.*, 
                   p.project_name
            from   sample s, project p
            where  s.sample_id=?
            and    s.project_id=p.project_id
        ],
    );
    $sth->execute($sample_id);
    my $sample = $sth->fetchrow_hashref;

    if (!$sample) {
        return $self->reply->exception("Bad sample id ($sample_id)");
    }

    $sample->{'attrs'} = $dbh->selectall_arrayref(
        q'
            select t.type, a.attr_value, t.url_template
            from   sample_attr_type t, sample_attr a
            where  a.sample_id=?
            and    a.sample_attr_type_id=t.sample_attr_type_id
        ', 
        { Columns => {} },
        $sample_id
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $sample );
        },

        html => sub {
            $self->layout('default');

            $self->render( sample => $sample );
        },

        txt => sub {
            $self->render( text => dump($sample) );
        },
    );
}

1;

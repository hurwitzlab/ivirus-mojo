package IVirus::Controller::Assembly;

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
                'list' => {
                    params => {
                        project_id => {
                            type => 'int',
                            desc => 'value of the project id to which the '
                                 .  'assemblies belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of assemblies',
                },

                'view' => {
                    params => {
                        assembly_id => {
                            type => 'int',
                            desc => 'the assembly id',
                            required => 'true'
                        }
                    },
                    results => 'the details of an assembly',
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
        select a.assembly_id, a.assembly_code, a.assembly_name,
               a.organism, a.cds_file, a.nt_file, a.pep_file,
               p.project_id, p.project_name
        from   assembly a, project p
        where  a.project_id=p.project_id
    ];

    if (my $project_id = $self->req->param('project_id')) {
        $sql .= sprintf('and a.project_id=%s', $dbh->quote($project_id));
    }

    my $assemblies = $dbh->selectall_arrayref($sql, { Columns => {} });

    $self->respond_to(
        json => sub {
            $self->render( json => $assemblies );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assemblies => $assemblies,
                title      => 'Assemblies',
            );
        },

        txt => sub {
            $self->render( text => dump($assemblies) );
        },

        tab => sub {
            my $text = '';

            if (@$assemblies) {
                my @flds = sort keys %{ $assemblies->[0] };
                my @data = (join "\t", @flds);
                for my $asm (@$assemblies) {
                    push @data, join "\t", map { $asm->{$_} // '' } @flds;
                }
                $text = join "\n", @data;
            }

            $self->render( text => $text );
        },
    );
}

# ----------------------------------------------------------------------
sub view {
    my $self        = shift;
    my $assembly_id = $self->param('assembly_id');
    my $dbh         = IVirus::DB->new->dbh;

    my $sth = $dbh->prepare(
        q[
            select a.assembly_id, a.assembly_code, a.assembly_name,
                   a.organism, a.cds_file, a.nt_file, a.pep_file,
                   p.project_id, p.project_name
            from   assembly a, project p
            where  a.assembly_id=?
            and    a.project_id=p.project_id
        ]
    );
    $sth->execute($assembly_id);
    my $assembly = $sth->fetchrow_hashref;

    if (!$assembly) {
        return $self->reply->exception("Bad assembly id ($assembly_id)");
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $assembly );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assembly => $assembly,
                title    => sprintf('Assembly: %s', 
                    $assembly->{'assembly_name'} || $assembly->{'organism'}
                ),
            );
        },

        txt => sub {
            $self->render( text => dump($assembly) );
        },
    );
}

1;

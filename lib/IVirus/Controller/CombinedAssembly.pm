package IVirus::Controller::CombinedAssembly;

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
                                 .  'combined assemblies belong',
                            required => 'false',
                        }
                    },
                    results => 'a list of combined assemblies',
                },

                view => {
                    params => {
                        combined_assembly_id => {
                            type     => 'int',
                            desc     => 'the combined assembly id',
                            required => 'true'
                        }
                    },
                    results => 'the details of a combined assembly',
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
        select a.combined_assembly_id, a.assembly_name,
               a.phylum, a.class, a.family,
               a.genus, a.species, a.strain, a.pcr_amp,
               a.annotations_file, a.peptides_file,
               a.nucleotides_file, a.cds_file,
               p.project_id, p.project_name
        from   combined_assembly a, project p
        where  a.project_id=p.project_id
    ];

    if (my $project_id = $self->param('project_id')) {
        $sql .= sprintf('and a.project_id=%s', $dbh->quote($project_id));
    }

    my $assemblies = $dbh->selectall_arrayref($sql, { Columns => {} });
    
    for my $asm (@$assemblies) {
        $asm->{'samples'} = $dbh->selectall_arrayref(
            q[
                select s.sample_id, s.sample_name
                from   combined_assembly_to_sample c2s,
                       sample s
                where  c2s.combined_assembly_id=?
                and    c2s.sample_id=s.sample_id
            ], 
            { Columns => {} }, 
            $asm->{'combined_assembly_id'}
        );

        $asm->{'sample_names'} = join ', ', 
            map { $_->{'sample_name'} } @{ $asm->{'samples'} };
    }

    $self->respond_to(
        json => sub {
            $self->render( json => $assemblies );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                title      => 'Combined Assemblies', 
                assemblies => $assemblies 
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
                    push @data, join "\t", 
                        map { s/[\r\n]//g; $_ }
                        map { 
                            ref $asm->{$_} eq 'ARRAY' 
                            ? '-'
                            : $asm->{$_} // '' 
                        } @flds;
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
    my $assembly_id = $self->param('combined_assembly_id');
    my $dbh         = IVirus::DB->new->dbh;

    if ($assembly_id =~ /^\D/) {
        my $sql = q[
            select combined_assembly_id 
            from   combined_assembly 
            where  assembly_name=?
        ];

        if (my $id = $dbh->selectrow_array($sql, {}, $assembly_id)) {
            $assembly_id = $id;
        }
    }

    my $sth = $dbh->prepare(
        q[
            select a.combined_assembly_id, a.assembly_name,
                   a.phylum, a.class, a.family,
                   a.genus, a.species, a.strain, a.pcr_amp,
                   a.annotations_file, a.peptides_file,
                   a.nucleotides_file, a.cds_file,
                   p.project_id, p.project_name
            from   combined_assembly a, project p
            where  a.combined_assembly_id=?
            and    a.project_id=p.project_id
        ]
    );
    $sth->execute($assembly_id);
    my $assembly = $sth->fetchrow_hashref;

    if (!$assembly) {
        return 
        $self->reply->exception("Bad combined assembly id ($assembly_id)");
    }

    $assembly->{'samples'} = $dbh->selectall_arrayref(
        q[
            select s.sample_id, s.sample_name
            from   combined_assembly_to_sample ca2s, sample s
            where  ca2s.combined_assembly_id=?
            and    ca2s.sample_id=s.sample_id
        ],
        { Columns => {} },
        $assembly_id
    );

    $self->respond_to(
        json => sub {
            $self->render( json => $assembly );
        },

        html => sub {
            $self->layout('default');

            $self->render( 
                assembly => $assembly,
                title    => sprintf(
                    "Combined Assembly: %s", 
                    $assembly->{'assembly_name'} || 'Unknown'
                ),
            );
        },

        txt => sub {
            $self->render( text => dump($assembly) );
        },
    );
}

1;

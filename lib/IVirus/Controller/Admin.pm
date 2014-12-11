package IVirus::Controller::Admin;

use IVirus::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

# ----------------------------------------------------------------------
sub create_project_page {
    my $self       = shift;
    my $project_id = $self->param('project_id')    or die 'No project id';
    my $title      = $self->param('title')         or die 'No title';
    my $contents   = $self->param('contents')      or die 'No contents';
    my $order      = $self->param('display_order') || '1';
    my $format     = $self->param('format')        || 'html';
    my $db         = IVirus::DB->new;
    my $schema     = $db->schema;

    my $Page          = $schema->resultset('ProjectPage')->create({
        project_id    => $project_id,
        title         => $title,
        contents      => $contents,
        display_order => $order,
        format        => lc $format,
    });

    return $self->redirect_to("/admin/view_project_pages/$project_id");
}

# ----------------------------------------------------------------------
sub create_project_page_form {
    my $self       = shift;
    my $project_id = $self->param('project_id');
    my $db         = IVirus::DB->new;
    my $Project    = $db->schema->resultset('Project')->find($project_id);

    $self->layout('admin');
    $self->render(project => $Project);
}

# ----------------------------------------------------------------------
sub delete_publication {
    my $self   = shift;
    my $pub_id = $self->param('publication_id');
    my $db     = IVirus::DB->new;
    my $schema = $db->schema;
    my $Pub    = $schema->resultset('Publication')->find($pub_id);

    $Pub->delete();

    $self->respond_to(
        json => sub {
            $self->render( json => { result  => 'ok' });
        },

        html => sub {
            return $self->redirect_to("/admin/list_publications");
        },
    );
}

# ----------------------------------------------------------------------
sub delete_project {
    my $self       = shift;
    my $project_id = $self->param('project_id');
    my $db         = IVirus::DB->new;
    my $schema     = $db->schema;
    my $Project    = $schema->resultset('Project')->find($project_id);

    $Project->delete();

    $self->respond_to(
        json => sub {
            $self->render( json => { result  => 'ok' });
        },

        html => sub {
            return $self->redirect_to("/admin/list_projects");
        },
    );
}

# ----------------------------------------------------------------------
sub delete_project_page {
    my $self       = shift;
    my $pp_id      = $self->param('project_page_id');
    my $db         = IVirus::DB->new;
    my $schema     = $db->schema;
    my $Page       = $schema->resultset('ProjectPage')->find($pp_id);
    my $project_id = $Page->project_id;

    $Page->delete();

    $self->respond_to(
        json => sub {
            $self->render( json => { result  => 'ok' });
        },

        html => sub {
            return $self->redirect_to("/admin/edit_project/$project_id");
        },
    );
}

# ----------------------------------------------------------------------
sub delete_sample {
    my $self       = shift;
    my $sample_id  = $self->param('sample_id');
    my $db         = IVirus::DB->new;
    my $schema     = $db->schema;
    my $Sample     = $schema->resultset('Sample')->find($sample_id);
    my $project_id = $Sample->project_id;

    $Sample->delete();

    $self->respond_to(
        json => sub {
            $self->render( json => { result  => 'ok' });
        },

        html => sub {
            return $self->redirect_to("/admin/list_samples/$project_id");
        },
    );
}

# ----------------------------------------------------------------------
sub edit_project {
    my $self       = shift;
    my $project_id = $self->param('project_id');
    my $db         = IVirus::DB->new;

    my $sql = sprintf(
        'select project_id from project where %s=?',
        $project_id =~ /\D+/ ? 'project_code' : 'project_id'
    );

    my $sth = $db->dbh->prepare($sql);
    $sth->execute($project_id);
    my $id = $sth->fetchrow_hashref;

    my $Project = $db->schema->resultset('Project')->find($project_id);

    my $num_pages = $db->dbh->selectrow_array(
        'select count(*) from project_page where project_id=?', {},
        $project_id
    );

    $self->layout('admin');
    $self->render( 
        project   => $Project,
        num_pages => $num_pages,
        title     => 'Edit Project',
    );
}

# ----------------------------------------------------------------------
sub edit_project_page {
    my $self   = shift;
    my $db     = IVirus::DB->new;
    my $schema = $db->schema;
    my $pp_id  = $self->param('project_page_id');
    my $Page   = $schema->resultset('ProjectPage')->find($pp_id);

    $self->layout('admin');
    $self->render( 
        title   => 'Create Project Page',
        page    => $Page,
    );
}

# ----------------------------------------------------------------------
sub index {
    my $self = shift;
    $self->layout('admin');
    $self->render;
}

# ----------------------------------------------------------------------
sub list_projects {
    my $self     = shift;
    my $dbh      = IVirus::DB->new->dbh;
    my $projects = $dbh->selectall_arrayref(
        'select * from project', { Columns => {} }
    );

    $self->layout('admin');
    $self->render(projects => $projects);
}

# ----------------------------------------------------------------------
sub list_publications {
    my $self = shift;
    my $dbh  = IVirus::DB->new->dbh;
    my $pubs = $dbh->selectall_arrayref(
        'select * from publication', { Columns => {} }
    );

    $self->respond_to(
        json => sub {
            $self->render( json => {
                Result  => 'OK',
                Records => $pubs 
            });
        },

        html => sub {
            $self->layout('admin');
            $self->render(pubs => $pubs);
        },
    );
}

# ----------------------------------------------------------------------
sub list_samples {
    my $self       = shift;
    my $project_id = $self->param('project_id');
    my $db         = IVirus::DB->new;
    my $Project    = $db->schema->resultset('Project')->find($project_id);
    my $samples    = $db->dbh->selectall_arrayref(
        'select * from sample where project_id=?', { Columns => {} },
        $project_id
    );

    $self->layout('admin');
    $self->render(
        project => $Project,
        samples => $samples,
    );
}

# ----------------------------------------------------------------------
sub update_project {
    my $self       = shift;
    my $req        = $self->req;
    my $project_id = $req->param('project_id');

    my @flds = qw[ 
        project_name pi institution project_code project_type description 
    ];
    my @vals = map { $req->param($_) } @flds;

    my $dbh  = IVirus::DB->new->dbh;
    my $sql  = sprintf(
        'update project set %s where project_id=?',
        join(', ', map { "$_=?" } @flds),
    );
        
    $dbh->do($sql, {}, @vals, $project_id);

    return $self->redirect_to("/admin/edit_project/$project_id");
}

# ----------------------------------------------------------------------
sub update_project_page {
    my $self       = shift;
    my $id         = $self->param('project_page_id') or die 'No page id';
    my $title      = $self->param('title')           or die 'No title';
    my $contents   = $self->param('contents')        or die 'No contents';
    my $order      = $self->param('display_order')   || '1';
    my $format     = $self->param('format')          || 'html';
    my $db         = IVirus::DB->new;
    my $schema     = $db->schema;

    my $Page = $schema->resultset('ProjectPage')->find($id);
    $Page->title($title);
    $Page->contents($contents);
    $Page->display_order($order);
    $Page->format(lc $format);
    $Page->update();

    my $project_id = $Page->project_id;
    return $self->redirect_to("/admin/view_project_pages/$project_id");
}

# ----------------------------------------------------------------------
sub update_publication {
    my $self   = shift;
    my $req    = $self->req;
    my $pub_id = $req->param('publication_id');

    my @flds = qw[ 
        title author journal pub_code pub_date doi pubmed_id project_id
    ];
    my @vals = map { $req->param($_) } @flds;

    my $dbh  = IVirus::DB->new->dbh;
    my $sql  = sprintf(
        'update publication set %s where publication_id=?',
        join(', ', map { "$_=?" } @flds),
    );
        
    $dbh->do($sql, {}, @vals, $pub_id);

    return $self->redirect_to('/admin/list_publications');
}

# ----------------------------------------------------------------------
sub view_project {
    my $self       = shift;
    my $req        = $self->req;
    my $project_id = $self->param('project_id');
    my $db         = IVirus::DB->new;
    my $Project    = $db->schema->resultset('Project')->find($project_id);

    $self->layout('admin');
    $self->render(
        project => $Project
    );
}

# ----------------------------------------------------------------------
sub view_project_pages {
    my $self       = shift;
    my $project_id = $self->param('project_id');
    my $db         = IVirus::DB->new;
    my $Project    = $db->schema->resultset('Project')->find($project_id);
    my $pages      = $db->dbh->selectall_arrayref(
        'select * from project_page where project_id=?', 
        { Columns => {} }, 
        $project_id
    );


    $self->layout('admin');
    $self->render(pages => $pages, project => $Project);
}

# ----------------------------------------------------------------------
sub view_publication {
    my $self           = shift;
    my $req            = $self->req;
    my $publication_id = $self->param('publication_id');

    my $db  = IVirus::DB->new;
    my $Pub = $db->schema->resultset('Publication')->find($publication_id);

    $self->layout('admin');
    $self->render(pub => $Pub);
}

1;

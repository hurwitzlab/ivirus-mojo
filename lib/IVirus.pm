package IVirus;

use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    $self->plugin('tt_renderer');

    $self->plugin('JSONConfig', { file => 'ivirus.json' });

    my $r = $self->routes;

    # 
    # Admin endpoints
    # 
    $r->get('/admin')->to('admin#index');

    $r->post('/admin/create_project_page')->to('admin#create_project_page');

    $r->get('/admin/create_project_page_form/:project_id')->to('admin#create_project_page_form');

    $r->post('/admin/delete_publication/:publication_id')->to('admin#delete_publication');

    $r->post('/admin/delete_project/:project_id')->to('admin#delete_project');

    $r->post('/admin/delete_project_page/:project_page_id')->to('admin#delete_project_page');

    $r->post('/admin/delete_sample/:sample_id')->to('admin#delete_sample');

    $r->get('/admin/edit_project_page/:project_page_id')->to('admin#edit_project_page');

    $r->get('/admin/list_projects')->to('admin#list_projects');

    $r->get('/admin/list_publications')->to('admin#list_publications');

    $r->get('/admin/list_samples/:project_id')->to('admin#list_samples');

    $r->post('/admin/update_project_page')->to('admin#update_project_page');

    $r->get('/admin/edit_project/:project_id')->to('admin#edit_project');

    $r->get('/admin/view_project/:project_id')->to('admin#view_project');

    $r->get('/admin/view_project_pages/:project_id')->to('admin#view_project_pages');

    $r->get('/admin/view_publication/:publication_id')->to('admin#view_publication');

    $r->post('/admin/update_project')->to('admin#update_project');

    $r->post('/admin/update_publication')->to('admin#update_publication');

    #
    # User endpoints
    #
    $r->get('/')->to('welcome#index');

    $r->get('/assembly/info')->to('assembly#info');

    $r->get('/assembly/list')->to('assembly#list');

    $r->get('/assembly/view/:assembly_id')->to('assembly#view');

    #$r->get('/carousel')->to('welcome#carousel');

    $r->get('/combined_assembly/info')->to('combined_assembly#info');

    $r->get('/combined_assembly/list')->to('combined_assembly#list');

    $r->get('/combined_assembly/view/:combined_assembly_id')->to('combined_assembly#view');

    $r->get('/download')->to('download#format');

    $r->post('/download/get')->to('download#get');

    $r->get('/feedback')->to('feedback#form');

    $r->post('/feedback/submit')->to('feedback#submit');

    $r->get('/index')->to('welcome#index');

    $r->get('/info')->to('welcome#index');

    $r->get('/project/info')->to('project#info');

    $r->get('/project/browse')->to('project#browse');

    $r->get('/project/list')->to('project#list');

    $r->get('/project/view/:project_id')->to('project#view');

    $r->get('/project_page/info')->to('project_page#info');

    $r->get('/project_page/view/:project_page_id')->to('project_page#view');

    $r->get('/pubchase/info')->to('pubchase#info');

    $r->get('/pubchase/list')->to('pubchase#list');

    $r->get('/publication/info')->to('publication#info');

    $r->get('/publication/list')->to('publication#list');

    $r->get('/publication/view/:publication_id')->to('publication#view');

    $r->get('/reference/info')->to('reference#info');

    $r->get('/reference/list')->to('reference#list');

    $r->get('/sample/info')->to('sample#info');

    $r->get('/sample/list')->to('sample#list');

    $r->get('/sample/view/:sample_id')->to('sample#view');

    $r->get('/search')->to('search#results');

    $r->get('/search/info')->to('search#info');

    $self->hook(
        before_render => sub {
            my ($c, $args) = @_;

            return unless my $template = $args->{'template'};

            if ($c->accepts('html')) {
                $args->{'title'} = ucfirst $template;
                $c->layout('default');
            }
            elsif ($c->accepts('json')) {
                $args->{'json'} = {
                    status    => $args->{'status'},
                    exception => $args->{'exception'},
                };
            }
        }
    );

    $self->hook(
        after_dispatch => sub {
            my $c = shift;
            if ( defined $c->param('download') ) {
                $c->res->headers->add(
                    'Content-type' => 'application/force-download' );

                (my $file = $c->req->url->path) =~ s{.+/}{};
                my $name = $c->param('download') || '';

                if ($name =~ /\D/) {
                    $file = $name;
                }

                $c->res->headers->add(
                    'Content-Disposition' => qq[attachment; filename=$file] );
            }
        }
    );
}

1;

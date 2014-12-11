package IVirus::Controller::Download;

use IVirus::DB;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dump 'dump';

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
sub format {
    my $self = shift;

    $self->layout('default');
    $self->render(title => 'Select format');
}

# ----------------------------------------------------------------------
sub get {
    my $self   = shift;
    my $url    = $self->param('url')    or die 'No URL';
    my $format = $self->param('format') || 'json';
    my $URL    = Mojo::URL->new($url);
    (my $path  = $URL->path) =~ s/\.html$//;
    my $name   = $path;
    $name      =~ s{^/}{}g;
    $name      =~ s{/}{-}g;
    $URL->query->param('download' => $name); 
    my $new    = $path . '.' . $format . '?' . $URL->query;

    return $self->redirect_to($new);
}

1;

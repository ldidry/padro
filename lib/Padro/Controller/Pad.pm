package Padro::Controller::Pad;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub display {
    my $c    = shift;
    my $name = $c->param('pad');

    my $pad = $c->find_or_fetch($name);

    return $c->reply->exception('Pad not found!') unless (defined($pad));

    $pad->{html} =~ s#<!DOCTYPE HTML><html><body>(.*)</body></html>#$1#;

    $c->render(
        pad => $pad
    );
}

sub dl_text {
    my $c    = shift;
    my $name = $c->param('pad');

    my $pad  = $c->find_or_fetch($name);

    my $filename     = $name.'.txt';

    my $headers = Mojo::Headers->new();
    $headers->add('Content-Type', 'text/plain;name='.$filename);
    $headers->add('Content-Disposition', 'attachment;filename='.$filename);
    $c->res->content->headers($headers);

    $c->render(
        template => undef,
        text    => $pad->{text},
    );
}

sub dl_html {
    my $c    = shift;
    my $name = $c->param('pad');

    my $pad  = $c->find_or_fetch($name);

    my $filename     = $name.'.html';

    my $headers = Mojo::Headers->new();
    $headers->add('Content-Type', 'text/html;name='.$filename);
    $headers->add('Content-Disposition', 'attachment;filename='.$filename);
    $c->res->content->headers($headers);

    $c->render(
        template => undef,
        text    => $pad->{html},
    );
}

1;

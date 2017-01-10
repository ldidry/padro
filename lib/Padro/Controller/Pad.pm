package Padro::Controller::Pad;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub display {
    my $c    = shift;
    my $name = $c->param('pad');
    my $rev  = $c->param('rev');

    $rev = undef unless $rev;

    my $pad = $c->find_or_fetch($name);

    return $c->reply->exception('Pad not found!') unless (defined($pad));

    if (defined $rev) {
        my $found = 0;
        for my $i (@{$pad->{revs}}) {
            if ($rev == $i->{rev}) {
                $found++;
                $pad->{html} = $i->{html};
                last;
            }
        }
        return $c->reply->exception('Revision not found!') unless ($found);
    }
    my $le = $pad->{last_edition};
    $pad->{last_edition} = {};
    if ($le) {
        $le =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
        $pad->{last_edition} = {
            year   => $1,
            month  => $2,
            day    => $3,
            hour   => $4,
            minute => $5,
            second => $6
        };
    }

    $pad->{html} =~ s#<!DOCTYPE HTML><html><body>(.*)</body></html>#$1# if defined $pad->{html};

    $c->render(
        pad => $pad,
        rev => $rev
    );
}

sub dl_text {
    my $c    = shift;
    my $name = $c->param('pad');
    my $rev  = $c->param('rev');

    $rev = undef unless $rev;

    my $pad  = $c->find_or_fetch($name);

    my $filename     = $name.'.txt';

    if (defined $rev) {
        my $found = 0;
        for my $i (@{$pad->{revs}}) {
            if ($rev == $i->{rev}) {
                $found = 1;
                $pad->{text} = $i->{text};
            }
        }
        return $c->reply->exception('Revision not found!') unless ($found);
    }

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
    my $rev  = $c->param('rev');

    $rev = undef unless $rev;

    my $pad  = $c->find_or_fetch($name);

    my $filename     = $name.'.html';

    if (defined $rev) {
        my $found = 0;
        for my $i (@{$pad->{revs}}) {
            if ($rev == $i->{rev}) {
                $found = 1;
                $pad->{html} = $i->{html};
            }
        }
        return $c->reply->exception('Revision not found!') unless ($found);
    }

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

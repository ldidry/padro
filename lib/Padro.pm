package Padro;
use Mojo::Base 'Mojolicious';
use Mojo::Pg;
use Mojo::Pg::Migrations;
use Etherpad;

# This method will run once at server start
sub startup {
    my $self = shift;

    push @{$self->app->commands->namespaces}, 'Padro::Command';

    # Get config
    my $config = $self->plugin('config', default =>
        {
            db => {
                database => 'padro',
                host     => 'localhost',
            },
            theme => 'default',
        }
    );

    $self->plugin('Minion' => {SQLite => 'sqlite:minion.db'});

    # Themes handling
    shift @{$self->renderer->paths};
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_file('themes/'.$config->{theme});
        push @{$self->renderer->paths}, $theme.'/templates' if -d $theme.'/templates';
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->renderer->paths}, $self->home->rel_file('themes/default/templates');
    push @{$self->static->paths}, $self->home->rel_file('themes/default/public');

    # Hooks
    $self->hook(after_static => sub {
        my $c = shift;
        $c->res->headers->cache_control('max-age=2592000, must-revalidate');
    });

    # Internationalization
    my $lib = $self->home->rel_file('themes/'.$config->{theme}.'/lib');
    eval qq(use lib "$lib");
    $self->plugin('I18N');

    # Debug
    $self->plugin('DebugDumperHelper');

    # Add new MIME type
    $self->types->type(txt => 'text/plain; charset=utf-8');

    # Helpers
    $self->helper(
        pg => sub {
            my $c     = shift;
            my $addr  = 'postgresql://';
            $addr    .= $c->config->{db}->{host};
            $addr    .= ':'.$c->config->{db}->{port} if defined $c->config->{db}->{port};
            $addr    .= '/'.$c->config->{db}->{database};
            state $pg = Mojo::Pg->new($addr);
            $pg->password($c->config->{db}->{pwd});
            $pg->username($c->config->{db}->{user});
            return $pg;
        }
    );

    $self->helper(
        ep => sub {
            my $c     = shift;
            state $ep = Etherpad->new($c->config->{ep});
            return $ep;
        }
    );

    $self->helper(
        find_or_fetch => sub {
            my $c       = shift;
            my $name    = shift;

            my $db = $c->app->pg->db;

            my $results = $db->query('SELECT * FROM pads WHERE name = (?)', $name);

            if ($results->rows == 1) {
                my $pad = $results->hash;

                my $r = $db->query('SELECT authors.name FROM authors JOIN pad_has_authors ON authors.ep_id = pad_has_authors.author_id WHERE pad_has_authors.pad_id = (?) ORDER BY authors.name', $name);

                $pad->{authors} = $r->hashes if ($r->rows > 0);

                $r = $db->query('SELECT rev, html, text FROM revisions WHERE pad_id = (?) ORDER BY rev DESC', $name);

                $pad->{revs} = $r->hashes if ($r->rows > 0);
                return $pad;
            } elsif ($results->rows > 1) {
                $c->app->log->error('More than one row returned when looking for a pad, this is not supposed to happen!');

                return undef;
            } else {
                my $ep         = $c->app->ep;
                my $revisions  = $ep->get_revisions_count($name);

                # This is an empty pad
                return undef unless ($revisions);

                $c->app->minion->enqueue(fetch_authors_of_pad         => [$name]);
                $c->app->minion->enqueue(fetch_saved_revisions_of_pad => [$name]);
                $c->app->minion->enqueue(fetch_pad_text               => [$name]);
                $c->app->minion->enqueue(fetch_pad_html               => [$name]);
                $c->app->minion->enqueue(fetch_pad_last_edition       => [$name]);

                my $r = $db->query('INSERT INTO pads (name, revisions) VALUES (?, ?) RETURNING *', ($name, $revisions));

                return $r->hash;
            }
        }
    );

    # Minion tasks
    $self->app->minion->add_task(
        fetch_pad => sub {
            my $job  = shift;
            my $name = shift;

            my $ep        = $job->app->ep;
            my $revisions = $ep->get_revisions_count($name);

            # This is an empty pad
            return undef unless ($revisions);

            $job->app->minion->enqueue(fetch_authors_of_pad         => [$name]);
            $job->app->minion->enqueue(fetch_saved_revisions_of_pad => [$name]);
            $job->app->minion->enqueue(fetch_pad_text               => [$name]);
            $job->app->minion->enqueue(fetch_pad_html               => [$name]);
            $job->app->minion->enqueue(fetch_pad_last_edition       => [$name]);

            $job->app->pg->db->query('INSERT INTO pads (name, revisions) VALUES (?, ?) RETURNING *', ($name, $revisions));
        }
    );
    $self->app->minion->add_task(
        fetch_authors_of_pad => sub {
            my $job = shift;
            my $pad = shift;

            my $ep = $job->app->ep;

            my $authors = $ep->list_authors_of_pad($pad);

            if (defined $authors) {
                my $nb = scalar @{$authors};
                $job->app->pg->db->query('UPDATE pads SET authors_nb = ? WHERE name = ?', ($nb, $pad));
                for my $author (@{$authors}) {
                    $job->app->minion->enqueue(fetch_author_information => [($pad, $author)]);
                }
            } else {
                say 'Error while fetching authors of pad '.$pad.' from etherpad';
                #$job->app->minion->enqueue(fetch_authors_of_pad => [$pad]);
            }
        }
    );
    $self->app->minion->add_task(
        fetch_author_information => sub {
            my $job    = shift;
            my $pad_id = shift;
            my $ep_id  = shift;

            my $db = $job->app->pg->db;

            my $results = $db->query('SELECT * FROM authors WHERE ep_id = ?', $ep_id);

            if ($results->rows == 0) {
                my $ep   = $job->app->ep;
                my $name = $ep->get_author_name($ep_id);
                $name = 'anonymous' unless (defined($name));

                $db->query('INSERT INTO authors (ep_id, name) VALUES (?, ?)', ($ep_id, $name));

                $db->query('INSERT INTO pad_has_authors (author_id, pad_id) VALUES (?, ?)', ($ep_id, $pad_id));
            } else {
                my $results = $db->query('SELECT * FROM pad_has_authors WHERE pad_id = ? AND author_id = ?', ($pad_id, $ep_id));
                $db->query('INSERT INTO pad_has_authors (author_id, pad_id) VALUES (?, ?)', ($ep_id, $pad_id)) if ($results->rows == 0);
            }
        }
    );
    $self->app->minion->add_task(
        fetch_saved_revisions_of_pad => sub {
            my $job = shift;
            my $pad = shift;

            my $ep = $job->app->ep;

            my $revs = $ep->list_saved_revisions($pad);

            if (defined $revs) {
                for my $rev (@{$revs}) {
                    $job->app->minion->enqueue(fetch_saved_rev => [($pad, $rev)]);
                }
            } else {
                say 'Error while fetching saved revisions of pad '.$pad.' from etherpad';
                #$job->app->minion->enqueue(fetch_saved_revisions_of_pad => [$pad]);
            }
        }
    );
    $self->app->minion->add_task(
        fetch_saved_rev => sub {
            my $job = shift;
            my $pad = shift;
            my $rev = shift;

            my $ep = $job->app->ep;
            my $db = $job->app->pg->db;

            my $text = $ep->get_text($pad, $rev);
            my $html = $ep->get_html($pad, $rev);

            if (defined $text && defined $html) {
                $db->query('INSERT INTO revisions (pad_id, rev, text, html) VALUES (?, ?, ?, ?)', ($pad, $rev, $text, $html));
            } elsif (!defined $text) {
                say 'Error while fetching text of revision '.$rev.' of pad_id '.$pad.' from etherpad';
                $db->query('INSERT INTO revisions (pad_id, rev, html) VALUES (?, ?, ?, ?)', ($pad, $rev, $html));
            } elsif (!defined $html) {
                say 'Error while fetching html of revision '.$rev.' of pad_id '.$pad.' from etherpad';
                $db->query('INSERT INTO revisions (pad_id, rev, text) VALUES (?, ?, ?, ?)', ($pad, $rev, $text));
            } else {
                say 'Error while fetching html and text of revision '.$rev.' of pad_id '.$pad.' from etherpad';
                $db->query('INSERT INTO revisions (pad_id, rev) VALUES (?, ?, ?, ?)', ($pad, $rev));
            }
        }
    );
    $self->app->minion->add_task(
        fetch_pad_text => sub {
            my $job  = shift;
            my $name = shift;

            my $ep   = $job->app->ep;
            my $text = $ep->get_text($name);

            if (defined $text) {
                $job->app->pg->db->query('UPDATE pads set text = ? WHERE name = ?', ($text, $name));
            } else {
                say 'Error while fetching text of pad '.$name.' from etherpad';
                #$job->app->minion->enqueue(fetch_pad_text => [$name]);
            }
        }
    );
    $self->app->minion->add_task(
        fetch_pad_html => sub {
            my $job  = shift;
            my $name = shift;

            my $ep   = $job->app->ep;
            my $html = $ep->get_html($name);

            if (defined $html) {
                $job->app->pg->db->query('UPDATE pads set html = ? WHERE name = ?', ($html, $name));
            } else {
                say 'Error while fetching html of pad '.$name.' from etherpad';
                #$job->app->minion->enqueue(fetch_pad_html => [$name]);
            }
        }
    );
    $self->app->minion->add_task(
        fetch_pad_last_edition => sub {
            my $job  = shift;
            my $name = shift;

            my $ep   = $job->app->ep;
            my $time = $ep->get_last_edited($name);

            if (defined $time) {
                $time =~ s/\d{3}$//;
                my ($s, $m, $h, $day, $month, $year) = gmtime($time);
                my $last_edition = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $year + 1900, $month + 1, $day, $h, $m, $s);
                $job->app->pg->db->query('UPDATE pads set last_edition = ? WHERE name = ?', ($last_edition, $name));
            } else {
                say 'Error while fetching last edition time of pad '.$name.' from etherpad';
                $job->app->minion->enqueue(fetch_pad_last_edition => [$name]);
            }
        }
    );

    # Check Etherpad connection
    $self->app->ep->check_token();

    # Database migration
    my $migrations = Mojo::Pg::Migrations->new(pg => $self->pg);
    if ($self->mode eq 'development') {
        $migrations->from_file('migrations.sql')->migrate(0)->migrate(1);
        $self->app->minion->reset;
    } else {
        $migrations->from_file('migrations.sql')->migrate(1);
    }

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('misc#index');

    $r->get('/p/*pad')->to('pad#display');

    $r->get('/t/*pad')->to('pad#dl_text');

    $r->get('/h/*pad')->to('pad#dl_html');
}

1;

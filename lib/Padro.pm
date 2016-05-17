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
        }
    );

    my $addr  = 'postgresql://';
    $addr    .= $self->config->{minion}->{user};
    $addr    .= ':'.$self->config->{minion}->{pwd};
    $addr    .= '@'.$self->config->{minion}->{host};
    $addr    .= ':'.$self->config->{minion}->{port} if defined $self->config->{minion}->{port};
    $addr    .= '/'.$self->config->{minion}->{database};
    $self->plugin('Minion' => {Pg => $addr});

    # Themes handling
    shift @{$self->renderer->paths};
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_dir('themes/'.$config->{theme});
        push @{$self->renderer->paths}, $theme.'/templates' if -d $theme.'/templates';
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->renderer->paths}, $self->home->rel_dir('themes/default/templates');
    push @{$self->static->paths}, $self->home->rel_dir('themes/default/public');

    # Internationalization
    my $lib = $self->home->rel_dir('themes/'.$config->{theme}.'/lib');
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
            my $counter = shift || 0;

            my $db = $c->app->pg->db;

            my $results = $db->query('SELECT * FROM pads WHERE name = (?)', $name);

            if ($results->rows == 1) {
                my $r = $db->query('select authors.name from authors JOIN pad_has_authors ON authors.ep_id = pad_has_authors.author_id WHERE pad_has_authors.pad_id = (?) ORDER BY authors.name', $name);
                my $pad = $results->hash;
                $pad->{authors} = $r->hashes if ($r->rows > 0);
                return $pad;
            } elsif ($results->rows > 1) {
                $c->app->log->error('More than one row returned when looking for a pad, this is not supposed to happen!');

                return undef;
            } else {
                my $ep           = $c->app->ep;
                my $revisions    = $ep->get_revisions_count($name);

                # This is an empty pad
                return undef unless ($revisions);

                $c->app->minion->enqueue(fetch_authors_of_pad => [$name]);

                my $text         = $ep->get_text($name);
                my $html         = $ep->get_html($name);
                my $time         = $ep->get_last_edited($name);
                $time =~ s/\d{3}$//;
                my ($s, $m, $h, $day, $month, $year) = gmtime($time);
                my $last_edition = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $year + 1900, $month + 1, $day, $h, $m, $s);

                my $r = $db->query('INSERT INTO pads (name, text, html, revisions, last_edition) VALUES (?, ?, ?, ?, ?) RETURNING *', ($name, $text, $html, $revisions, $last_edition));

                return $r->hash;
            }
        }
    );

    # Minion tasks
    $self->app->minion->add_task(
        fetch_author_information => sub {
            my $job    = shift;
            my $pad_id = shift;
            my $ep_id  = shift;

            my $db = $job->app->pg->db;

            my $results = $db->query('SELECT * FROM authors WHERE ep_id = ?', $ep_id);

            if ($results->rows < 1) {
                my $ep   = $job->app->ep;
                my $name = $ep->get_author_name($ep_id);
                $name = 'anonymous' unless (defined($name));

                $db->query('INSERT INTO authors (ep_id, name) VALUES (?, ?)', ($ep_id, $name));
                $db->query('INSERT INTO pad_has_authors (author_id, pad_id) VALUES (?, ?)', ($ep_id, $pad_id));
            } else {
                $results = $db->query('SELECT * FROM pad_has_authors WHERE pad_id = ? AND author_id = ?', ($pad_id, $ep_id));
                if ($results->rows < 1) {
                    $db->query('INSERT INTO pad_has_authors (author_id, pad_id) VALUES (?, ?)', ($ep_id, $pad_id));
                }
            }
        }
    );
    $self->app->minion->add_task(
        fetch_authors_of_pad => sub {
            my $job = shift;
            my $pad = shift;

            my $ep = $job->app->ep;

            my @authors = $ep->list_authors_of_pad($pad);

            for my $author (@authors) {
                $job->app->minion->enqueue(fetch_author_information => [($pad, $author)]);
            }
        }
    );
    $self->app->minion->add_task(
        fetch_pad => sub {
            my $job  = shift;
            my $name = shift;

            my $ep           = $job->app->ep;
            my $revisions    = $ep->get_revisions_count($name);

            # This is an empty pad
            return undef unless ($revisions);

            $job->app->minion->enqueue(fetch_authors_of_pad => [$name]);

            my $text         = $ep->get_text($name);
            my $html         = $ep->get_html($name);
            my $time         = $ep->get_last_edited($name);
            $time =~ s/\d{3}$//;
            my ($s, $m, $h, $day, $month, $year) = gmtime($time);
            my $last_edition = sprintf('%04d-%02d-%02d %02d:%02d:%02d', $year + 1900, $month + 1, $day, $h, $m, $s);

            my $r = $job->app->pg->db->query('INSERT INTO pads (name, text, html, revisions, last_edition) VALUES (?, ?, ?, ?, ?)', ($name, $text, $html, $revisions, $last_edition));
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

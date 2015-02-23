package Padro::Command::get_all_pads;
use Mojo::Base 'Mojolicious::Commands';
use Term::ProgressBar;

has description => 'Fetch all pads.';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;
    my $file = shift;

    my @pads;
    if (defined($file)) {
        open my $f, '<', $file or die "Unable to open $file: $!";

        while (<$f>) {
            push @pads, $_;
        }
    } else {
        my $ep   = $c->app->ep;

        @pads = $ep->list_all_pads();
    }
    if (scalar(@pads)) {
        my $progress = Term::ProgressBar->new(
            {
                name => 'Enqueuing '.scalar(@pads).' pads',
                count => scalar(@pads),
                ETA   => 'linear'
            }
        );
        for my $pad (@pads) {
            $c->app->minion->enqueue(fetch_pad => [($pad)]) if (defined($pad));
            $progress->update();
        }
    } else {
        say "Empty list of pads. It can be normal or the result of a bad communication with the etherpad instance. Please check."
    }
}

1;

=encoding utf8

=head1 NAME

Padro::Command::get_all_pads - Get all pads from the configured etherpad instance and dumps them in database.

=head1 SYNOPSIS

  Usage: script/padro get_all_pads

=cut

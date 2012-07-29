# ABSTRACT: Event driven POSIX signal handling for ONE
package ONE::Signal;
use MooseX::Event;
use AnyEvent;
use Config ();

with 'MooseX::Event::Role::ClassMethods';

=event <SIG>

Where <SIG> is one of the signal names from Config's sig_name key.  Common
signals to trap include:

    HUP, INT, ALRM, USR1, USR2, TERM, CHLD

=cut

my @signals = split / /, $Config::Config{'sig_name'};

has_events @signals;

my %SETUP;

before on => sub {
    my $self = shift;
    use DDP;
    my $listener = pop;
    for ( @_ ) {
        next if exists $SETUP{$_};
        $self->setup_signal($_);
    }
};

my %SIGNAL;

sub setup_signal {
    my $self = shift;
    my( $signal ) = @_;
    return if exists $SETUP{$signal};

    my $emeta = $self->metaevent($signal);
    $emeta->on( first_listener => sub {
        $SIGNAL{$signal} = AE::signal $signal, sub { $self->emit($signal) };
    } );
    $emeta->on( no_listeners => sub {
        if ( exists $SIGNAL{$signal} ) {
            delete $SIGNAL{$signal};
        }
    } );

    $SETUP{$signal} = 1;
}

=classmethod method instance() returns ONE

Return the singleton object for this class

=cut

# We would just use MooseX::Singleton, but it's nice to maintain compatibility with Mouse
BEGIN {
    my $instance;
    sub instance {
        my $class = shift;
        return $instance ||= $class->new(@_);
    }
}

1;

=head1 SYNOPSIS

    # POSIX signals:
    use ONE::Signal;
    ONE::Signal->on( INT => event { ... } );

=head1 DESCRIPTION

This class lets you add event listeners to any POSIX signal.


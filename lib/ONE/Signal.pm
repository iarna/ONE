# ABSTRACT: Event driven POSIX signal handling for ONE
package ONE::Signal;
use MooseX::Event;
use AnyEvent;
use Config ();

with 'MooseX::Event::Role::ClassMethods';

has '_signal'  => (is=>'rw', default=>sub{{}}, init_arg=>undef);

=event <SIG>

Where <SIG> is one of the signal names from Config's sig_name key.  Common
signals to trap include:

    HUP, INT, ALRM, USR1, USR2, TERM, CHLD

=cut

has_events split / /, $Config::Config{'sig_name'};

sub BUILD {
    my $self = shift;
    $self->on( first_listener => sub {
        my $self = shift;
        my( $event ) = @_;
        if ( $event =~ /^[A-Z]+$/ ) {
            $self->_signal->{$event} = AE::signal $event, sub { $self->emit($event) };
        }
    } );
    $self->on( no_listeners   => sub {
        my $self = shift;
        my( $event ) = @_;
        if ( exists $self->_signal->{$event} ) {
            delete $self->_signal->{$event};
        }
    } );
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
    ONE::Signal->on( INT => sub { ... } );

=head1 DESCRIPTION

This class lets you add event listeners to any POSIX signal.


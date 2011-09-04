# ABSTRACT: Event driven POSIX signal handling for ONE
package ONE::Signal;
use MooseX::Event;
use AnyEvent;

with 'MooseX::Event::Role::ClassMethods';

has '_signal'  => (is=>'rw', default=>sub{{}}, init_arg=>undef);

=event <SIG>

Where <SIG> is one of the signal names below:

    HUP   INT  QUIT ILL  TRAP ABRT BUS    FPE    KILL
    USR1  SEGV USR2 PIPE ALRM TERM STKFLT CHLD   CONT
    STOP  TSTP TTIN TTOU URG  XCPU XFSZ   VTALRM PROF
    WINCH IO   PWR  SYS

Some of these may not actually be catchable (ie, KILL).  This is just the
list from "kill -l" on a modern Linux system.  Using one of these installs
any AnyEvent signal watcher. 

=cut


has_events qw(
    HUP   INT  QUIT ILL  TRAP ABRT BUS    FPE    KILL
    USR1  SEGV USR2 PIPE ALRM TERM STKFLT CHLD   CONT
    STOP  TSTP TTIN TTOU URG  XCPU XFSZ   VTALRM PROF
    WINCH IO   PWR  SYS );

=classmethod our method instance() returns ONE

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

sub activate_event {
    my $self = shift;
    my( $event ) = @_;
    $self->_signal->{$event} = AE::signal $event, sub { $self->emit($event) };
}

sub deactivate_event {
    my $self = shift;
    my( $event ) = @_;
    delete $self->_signal->{$event};
}

1;

=head1 SYNOPSIS

    # POSIX signals:
    use ONE::Signal;
    ONE::Signal->on( TERM => sub { ... } );

=head1 DESCRIPTION

This class lets you add event listeners to any POSIX signal.


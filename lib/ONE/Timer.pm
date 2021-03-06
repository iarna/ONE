package ONE::Timer;
# Dist::Zilla: +PodWeaver
# ABSTRACT: Timer/timeout events for MooseX::Event
use AnyEvent ();
use MooseX::Event;
use Scalar::Util ();

=attr Num|CodeRef $.delay is ro = 0

The number of seconds to delay before triggering this event.  By default, triggers immediately.

=cut
has 'delay'    => (isa=>'Num|CodeRef', is=>'ro', default=>0);


=attr Num $.interval is ro = 0

The number of seconds to delay

=cut
has 'interval' => (isa=>'Num', is=>'ro', default=>0);

has '_guard'   => (is=>'rw');

=event timeout

Emitted when the event time completes.

=cut

has_event 'timeout';

no MooseX::Event; # Remove the moose helpers now, so we can declare our own "after" method

=classmethod our method after( Rat $seconds, CodeRef $on_timeout ) returns ONE::Timer

Asynchronously, after $seconds, calls $on_timeout.  If you store the return
value, it acts as a guard-- if it's destroyed then the timer is canceled.

=cut

sub after {
    my $class = shift;
    my( $after, $on_timeout ) = @_;
    my $self = $class->new( delay=> $after );
    $self->on( timeout => $on_timeout );
    $self->start( defined(wantarray) );
    return $self;
}

=classmethod method at( Rat $epochtime, CodeRef $on_timeout ) returns ONE::Timer

Asychronously waits until $epochtime and then calls $on_timeout. If you store the
return value, it acts as a guard-- if it's destoryed then the timer is canceled.

=cut

sub at {
    my $class = shift;
    my( $at, $on_timeout ) = @_;
    my $self = $class->new( delay=> sub {$at - AE::time}  );
    $self->on( timeout => $on_timeout );
    $self->start( defined(wantarray) );
    return $self;
}

=classmethod method every( Rat $seconds, CodeRef $on_timeout ) returns ONE::Timer

Asychronously, after $seconds and every $seconds there after, calls $on-Timeout.  If you
store the return value it acts as a guard-- if it's destroyed then the timer is canceled.

=cut

sub every {
    my $class = shift;
    my( $every, $on_timeout ) = @_;
    my $self = $class->new( delay => $every, interval => $every );
    $self->on( timeout => $on_timeout );
    $self->start( defined(wantarray) );
    return $self;
}

=classmethod method new( :$delay, :$interval? ) returns ONE::Timer

Creates a new timer object that will emit it's "timeout" event after $delay
seconds and every $interval seconds there after.  Delay can be a code ref,
in which case it's return value is the number of seconds to delay.

=method method start( $is_obj_guard = False )

Starts the timer object running.  If $is_obj_guard is true, then destroying
the object will cancel the timer.

=cut

sub start {
    my $self = shift;
    my( $is_weak ) = @_;

    if ( defined $self->_guard ) {
        require Carp;
        Carp::croak( "Can't start a timer that's already running" );
    }

    my $cb;
    Scalar::Util::weaken($self) if $is_weak;
    if ( $self->interval ) {
        $cb = sub { $self->emit('timeout') };
    }
    else {
        $cb = sub { $self->cancel; $self->emit('timeout'); }
    }
    my $delay;
    if ( ref $self->delay ) {
        $delay = $self->delay->();
        $delay = 0 if $delay < 0;
    }
    else {
        $delay = $self->delay;
    }
    my $w = AE::timer $delay, $self->interval, $cb;
    $self->_guard( $w );
}

=method method cancel()

Cancels a running timer. You can start the timer again by calling the start
method.  For after and every timers, it begins waiting all over again. At timers will
still emit at the time you specified (or immediately if that time has passed).

=cut

sub cancel {
    my $self = shift;
    unless (defined $self->_guard) {
        require Carp;
        Carp::croak( "Can't cancel a timer that's not running" );
    }
    $self->_guard( undef );
}


__PACKAGE__->meta->make_immutable();

1;

=pod

=head1 SYNOPSIS

    use ONE::Timer;

    # After five seconds, say Hi
    ONE::Timer->after( 5, event { say "Hi!" } );

    # Two seconds from now, say At!
    ONE::Timer->at( time()+2, event { say "At!" } );

    # Every 5 seconds, starting 5 seconds from now, say Ping
    ONE::Timer->every( 5, event { say "Ping" } );

    my $timer = ONE::Timer->new( delay=>5, interval=>25 );

    $timer->on( timeout => event { say "Timer tick" } );

    $timer->start(); # Will say "Timer tick" in 5 secs and then ever 25 secs after that

    # ... later

    $timer->cancel(); # Will stop saying "Timer tick"

=for test_synopsis
use v5.10;

=head1 DESCRIPTION

Trigger events at a specific time or after a specific delay.

=head1 SEE ALSO

ONE
AnyEvent
http://nodejs.org/docs/v0.5.4/api/timers.html


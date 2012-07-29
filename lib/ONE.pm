# ABSTRACT: An object oriented approach to AnyEvent, using MooseX::Event
package ONE;
use MooseX::Event;
use Event::Wrappable;
use AnyEvent;

with 'MooseX::Event::Role::ClassMethods';

has '_loop_cv' => (is=>'rw', init_arg=>undef);
has '_idle_cv' => (is=>'rw', init_arg=>undef );


=event start

This is emitted just after the event loop is started up with ONE's loop
method.  Note that this will not be triggered if you start an event loop on
your own, or via a utility method (like ONE::Coro::sleep).  If you stop and
start the event loop repeatedly, this will be triggered repeatedly.

If you want code to execute when the event loop next starts, use ONE->next.
If you'll be the one starting the event loop, just pass the code to
ONE->loop.

=cut

has_event 'start';

=event stop

This is emitted just after the event loop is stopped with ONE's stop method.

=cut

has_event 'stop';

=event idle

This will be repeatedly emitted whenever the process is idle.  This is many
thousands of times per second on a modest system.  Attaching a once listener
to this is a way to defer code until any active events have finished
processing.

This is implemented as an AnyEvent idle watcher.

=cut

has_event 'idle';

=classmethod method instance() returns ONE

Return the singleton object for this class

=cut

# We would just use MooseX::Singleton, but it's nice to maintain compatibility with Mouse
BEGIN {
    my $instance;
    sub instance {
        my $class = shift;
        return $instance ||= $class->new();
    }
}



sub BUILD {
    my $instance = shift;
    my $idle_listener = event { $instance->emit('idle') };

    my $idle_meta = $instance->metaevent('idle');
    $idle_meta->on( add_listener => event {
        $instance->_idle_cv( AE::idle( $idle_listener ) );
    } );
    $idle_meta->on( no_listeners => event {
        $instance->_idle_cv( undef );
    } );
}

=classmethod method loop( CodeRef $next=undef )

Starts the main event loop.  This will return when the stop method is
called.  If you call start with an already active loop, the previous loop
will be stopped and a new one started, exactly as if you called stop()
before calling loop().

Calling this will emit a start event (but only after the previously active
loop was stopped).

You can optionally pass a coderef in-- if you do, it will be executed as
soon as the event loop has started up.  (It's equivalent to calling ->next
with the coderef prior to calling ->loop)

=cut

sub loop {
    my $invok = shift;
    my $self = ref($invok)? $invok: $invok->instance;
    if ( defined $self->_loop_cv ) {
        $self->stop();
    }
    $self->next(sub {
         my $self = shift;
         $self->emit('start');
    });
    if (@_) {
        my $todo = shift;
        $self->next($todo);
    }
    my $cv = AE::cv;
    $self->_loop_cv( $cv );
    $cv->recv();
}

=classmethod method stop()

Exits the main event loop and emits the stop event.  If no loop is active it
does nothing and does not emit an event.

=cut

sub stop {
    my $invok = shift;
    my $self = ref($invok)? $invok: $invok->instance;
    return unless defined $self->_loop_cv;
    $self->emit( 'stop' );
    $self->_loop_cv->send();
    delete $self->{'_loop_cv'};
}

=classmethod method next( CodeRef $todo )

This executes $todo at the next opportunity without actually doing so
immediately.  Basically, this falls back to the event loop and then executes
$todo.  That is:

    ONE->next(event { ... } );

Is conceptually the same as:

    AE::postpone { ... };

Except that the latter won't actually trigger a MooseX::Event style event and
so it won't be wrapped, provide a $self object, etc.

=cut
sub next {
    my $invok = shift;
    my $self = ref($invok)? $invok: $invok->instance;
    my($todo) = @_;
    if ( ! blessed($todo) or ! $todo->isa('Event::Wrappable') ) {
        $todo = &Event::Wrappable::event($todo);
    }
    my $postpone_watcher; $postpone_watcher = AE::timer( 0, 0, sub { undef $postpone_watcher; $self->$todo(); } );
}


sub import {
    my $class = shift;
    my $caller = caller;

    for (@_) {
        my($module,$args) = split /=/;
        my @args = split /[:]/, $args || "";

        local $@;
        eval "require ONE::$module;";
        if ( $@ ) {
            require Carp;
            Carp::croak( $@ );
        }
        eval "package $caller; ONE::$module->import(\@args);" if @args or !/=/;
        if ( $@ ) {
            require Carp;
            Carp::croak( $@ );
        }
    }

    no strict 'refs';
    *{$caller."::event"} = *Event::Wrappable::event;
}

=helper sub event( CodeRef $code ) returns CodeRef

Returns the wrapped code ref, to be passed to be an event listener.  This
code ref will be blessed as Event::Wrappable.

Originally defined in Event::Wrappable. This is exported into your namespace
when you use ONE.

=cut

__PACKAGE__->meta->make_immutable();
no MooseX::Event;

1;

=pod

=head1 SYNOPSIS

    use ONE;

    # Starting the main loop:
    ONE->loop;

    # We now block until either an event handler or Coro thread calls...

    # Stopping the main loop
    ONE->stop;

    # One shot and repeating timers:
    use ONE::Timer;
    ONE::Timer->after( $seconds => event { $do_something } );
    ONE::Timer->at( $time => event { $do_something } );
    ONE::Timer->every( $seconds => event { $do_something } );

    # Or with guards:
    my $timer = ONE::Timer->every( $seconds => event { $do_something } );
    $timer->cancel(); # Ends the timer
    $timer = undef;   # Also ends the timer

    # Coro/event loop safe sleeping
    use ONE::Sleep; # This is really AnyEvent::Sleep
    sleep $seconds;

    # POSIX signals:
    use ONE::Signal;
    ONE::Signal->on( TERM => event { $do_something } );

    # Called when the event loop is idle (if applicable)
    ONE->once( idle => event { $do_something } );

    # Trigger an event only after some other events have triggered

    use ONE::Collect; # Really just AnyEvent::Collect

    # Collect returns only after both events have been emitted
    collect {
         ONE::Timer->after( 2 => event { $do_something } );
         ONE::Timer->after( 3 => event { $do_something } );
    };

    # Call an event based API syncronously
    use ONE::Capture;

    # This is essentially the same thing as "sleep 2"
    capture { ONE::Timer->after( 2 => shift ) };

    # Event arguments become the return value:
    use AnyEvent::Socket qw( inet_aton );
    my @ips = capture { inet_aton( 'www.google.com', shift ) };


    # You can chain one modules on to the use line...
    use ONE qw( Timer Collect );

    # If you want to import something from them, use = like the perl commandline
    use ONE qw( Timer Sleep=sleep);

    # To import more then one symbol from a class, separate them with colons (:)
    use ONE qw( Timer Sleep=sleep:sleep_until Collect );

=for test_synopsis
use v5.10.0; my($do_something,$seconds,$time);

=head1 DESCRIPTION

ONE provides a layer on top of AnyEvent that uses MooseX::Event as it's
interface.  The goal of this suite of modules is to provide all of the
functionality of L<AnyEvent> but with the style and ease of use of Node.js.
This suite of classes is intended to be use by programs written in the
event-based style.

If you're looking to make a class that emits events, you should see
L<MooseX::Event>.

=head1 EVENT HANDLERS

All event handlers receive the object that emitted the event as their first argument,
along with any event specific arguments after that.  In the case of ONE::Timer, this object
is the guard object-- you can cancel a repeating timer in this fashion, even if you didn't
store the object to begin with.

=head1 COROUTINES

The event system that ONE is built on, L<MooseX::Event>, is L<Coro> aware,
and you do not need to use unblock_sub with any ONE event listeners.
L<MooseX::Event> listeners and thus by extenstion, ONE listeners, always run
in their own thread when L<Coro> is loaded.  As such, you can safely block
from them without risking deadlocks or other nastyness.

=head1 SEE ALSO

MooseX::Event
ONE::Timer
AnyEvent:Collect
ONE::Signal
ONE::Coro

=head1 RELATED

=over

=item L<AnyEvent>

=back


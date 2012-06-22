# ABSTRACT: A Node.js style AnyEvent class, using MooseX::Event
package ONE;
use MooseX::Event;
use AnyEvent;
use 5.10.0;

with 'MooseX::Event::Role::ClassMethods';

has '_loop_cv' => (is=>'rw', init_arg=>undef);
has '_idle_cv' => (is=>'rw', init_arg=>undef );


=event start

This is emitted just before the event loop is started up with ONE's loop method.  Note
that this will not be triggered if you start an event loop on your own, or via a utility
method (like ONE::Coro::sleep).

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

# This is used interanlly via ONE->next.  It should not be used directly as
# it would be an error to listen for it with 'on' versus 'once.'
has_event 'postpone';

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

sub BUILD {
    my $self = shift;
    $self->on( first_listener => sub {
        my $self = shift;
        my($event) = @_;
        given ($event) {
            when ('idle') {
                $self->_idle_cv( AE::idle( sub { $self->emit($event) } ) );
            }
            when ('postpone') {
                AE::postpone { $self->emit('postpone') }
            }
        }
    } );
    $self->on( no_listeners => sub {
        my $self = shift;
        my($event) = @_;
        return unless $event eq 'idle';
        $self->_idle_cv( undef );
    } );
}

=classmethod method loop()

Starts the main event loop.  This will return when the stop method is
called.  If you call start with an already active loop, the previous loop
will be stopped and a new one started, exactly as if you called stop()
before calling loop().

Calling this will emit a start event (but only after the previously active
loop was stopped).

=cut

sub loop {
    my $invok = shift;
    my $self = ref($invok)? $invok: $invok->instance;
    if ( defined $self->_loop_cv ) {
        $self->stop();
    }
    $self->emit( 'start' );
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

    ONE->next(sub { ... } );

Is conceptually the same as:

    AE::postpone { ... };

Except that the latter won't actually trigger a MooseX::Event style event and
so it won't be wrapped, provide a $self object, etc.

=cut
sub next {
    my $invok = shift;
    my $self = ref($invok)? $invok: $invok->instance;
    my($todo) = @_;
    $self->once( 'postpone', $todo );
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
    
}

__PACKAGE__->meta->make_immutable();
no MooseX::Event;

1;

=pod

=head1 SYNOPSIS

    use ONE;

    # Starting the main loop:
    ONE->loop;

    # Stopping the main loop (from an event handler or a Coro thread):
    ONE->stop;

    # One shot and repeating timers:
    use ONE::Timer;
    ONE::Timer->after( $seconds => sub { $do_something } );
    ONE::Timer->at( $time => sub { $do_something } );
    ONE::Timer->every( $seconds => sub { $do_something } );
    
    # Or with guards:
    my $timer = ONE::Timer->every( $seconds => sub { $do_something } );
    $timer->cancel(); # Ends the timer
    $timer = undef;   # Also ends the timer
    
    # Coro/event loop safe sleeping
    use ONE::Coro qw( sleep );
    sleep $seconds;
    
    # POSIX signals:
    use ONE::Signal;
    ONE::Signal->on( TERM => sub { $do_something } );

    # Called when the event loop is idle (if applicable)
    ONE->once( idle => sub { $do_something } );

    # Trigger an event only after some other events have triggered
    use ONE::Collect;
    my $group = ONE::Collect->group(sub {
        ONE::Timer->after( 2 => sub { $do_something } );
        ONE::Timer->after( 3 => sub { $do_something } );
        });
    $group->once( complete => sub { $do_something } );
    
    # Or procedurally:
    use ONE::Coro qw( collect );
    collect { # Return after both events have been emitted
         ONE::Timer->after( 2 => sub { $do_something } );
         ONE::Timer->after( 3 => sub { $do_something } );
    }; 


    # You can chain one modules on to the use line...
    use ONE qw( Timer Collect );
    
    # If you want to import something from them, use = like the perl commandline
    use ONE qw( Timer=sleep Collect );
    
    # To import more then one symbol from a class, separate from with colons (:)
    use ONE qw( Timer=sleep:sleep_until Collect );

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
ONE::Collect
ONE::Signal
ONE::Coro

=head1 RElATED

=over

=item L<AnyEvent>

=back


# ABSTRACT: Collect 
package ONE::Collect;
use MooseX::Event;
use AnyEvent;

has '_all_cv' => (isa=>'AnyEvent::CondVar', is=>'rw');

has '_any_cv' => (isa=>'AnyEvent::CondVar', is=>'rw');

=event first

This is emitted the first time any of the grouped events is emitted.

=cut

has_event 'first';

=event complete

This is emitted only after all of the grouped events have been emitted.

=cut

has_event 'complete';

=classmethod group( CodeRef $setup ) returns ONE::Collect

Make any event listeners created inside $setup a part of a new event group
and return that group.

=cut

=method group( CodeRef $setup )

Make any event listeners created inside $setup a part of this event group.  

=cut

sub group {
    my $class = shift;
    my( $setup ) = @_;
    my $self = ref($class)? $class : $class->new;
    my $wrapper = MooseX::Event->add_listener_wrapper(sub { $self->listener( @_ ) } );
    $setup->();
    MooseX::Event->remove_listener_wrapper( $wrapper );
    return $self;
}


=method listener( CodeRef $todo ) returns CodeRef

This wraps an event listener such that it will be a part of this group.

=cut

sub listener {
    my $self = shift;
    my( $todo ) = @_;
    
    my $all_cv = $self->_all_cv;
    my $any_cv = $self->_any_cv;
    unless ( $all_cv ) {
        $self->_all_cv( $all_cv = AE::cv { $self->emit('complete') });
        $self->_any_cv( $any_cv = AE::cv { $self->emit('first') });
    }

    # Begin processing
    $all_cv->begin;

    # Here we wrap the event listener and, after the first call, remove ourselves
    my $wrapped;
    $wrapped = sub { 
        my($self) = @_; # No shift to not disturb args
        $self->remove_listener( $self->current_event, $wrapped );
        $self->on( $self->current_event, $todo );
        $todo->(@_);
        $any_cv->send();
        $all_cv->end();
        undef $wrapped;
    };
    return $wrapped;
}

__PACKAGE__->meta->make_immutable();
no Any::Moose;


1;

=head1 SYNOPSIS

    use ONE::Collect;

    # Create an event group
    my $collect = ONE::Collect->group(sub {
        ONE::Timer->after( 2=> sub { say "two" } );
        ONE::Timer->after( 3=> sub { say "three" } );
    });

    # Collect some more events
    $collect->group(sub {
        ONE::Timer->after( 5=> sub { say "five" } );
    });

    # Manually group an event
    ONE::Timer->after( 4 => $collect->listener( sub { say "four" } ) );
    
    # Setup some listeners for the event group
    $collect->once( first    => sub { say "The first event fired" } );
    $collect->once( complete => sub { say "All events fired!" } );

=for test_synopsis
use 5.10.0;

=head1 DESCRIPTION

This allows you to reduce a group of unrelated events into a single event. 
Either when the first event is emitted, or after all events have been
emitted at least once.  

=head1 CAVEATS

Be aware when calling other people's code from an event group.  If they
setup event listeners those will be captured by your group as well.

=head1 SEE ALSO

ONE
ONE::Coro

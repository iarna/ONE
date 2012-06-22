# ABSTRACT: Procedural helpers for ONE
package ONE::Coro;
use strict;
use warnings;
use ONE qw( Timer Collect );
use Sub::Exporter -setup => {
    exports => [qw( collect collect_all collect_any sleep sleep_until )],
    };

=helper sub collect( &block ) is export
=helper sub collect_all( &block ) is export

Will return after all of the events declared inside the collect block have
been emitted at least once.

=cut

sub collect (&) {
    my $collect = ONE::Collect->group(@_);
    my $cv = AE::cv;
    $collect->once( complete => sub { $cv->send } );
    $cv->recv;
}

=helper sub collect_any( &block ) is export

Will return after any of the events declared inside the collect block have
been emitted at least once.  Note that it doesn't actually cancel the
unemitted events-- you'll have to do that yourself, if that's what you want.

=cut

sub collect_any (&) {
    my $collect = ONE::Collect->group(@_);
    my $cv = AE::cv;
    $collect->once( complete => sub { $cv->send } );
    $cv->recv;
}

=helper sub sleep( Rat $secs ) is export

Sleep for $secs while allowing events to emit (and Coroutine threads to run)

=cut

sub sleep {
    return if $_[-1] <= 0;
    my $cv = AE::cv;
    my $w=AE::timer( $_[-1], 0, sub { $cv->send } );
    $cv->recv;
    return;
}

=helper sub sleep_until( Rat $epochtime ) is export

Sleep until $epochtime while allowing events to emit (and Coroutine threads to run)

=cut

sub sleep_until {
    my $for = $_[-1] - AE::time;
    return if $for <= 0;
    my $cv = AE::cv;
    my $w=AE::timer( $for, 0, sub { $cv->send } );
    $cv->recv;
    return;
}

1;

=head1 SYNOPSIS

    use ONE::Coro qw( collect collect_any sleep );

    # Wait for all of a collection of events to trigger once:
    collect {
         ONE::Timer->after( 2 => sub { say "two" } );
         ONE::Timer->after( 3 => sub { say "three" } );
    }; # Returns after 3 seconds having printed "two" and "three"

    # Wait for any of a collection of events to trigger:
    collect_any {
        ONE::Timer->after( 2=> sub { say "two" } );
        ONE::Timer->after( 3=> sub { say "three" } );
    }; 
    # Returns after 2 seconds, having printed 2.  Note however that
    # the other event will still be emitted in another second.  If
    # you were to then execute the sleep below, it would print three.

    # Sleep for 3 seconds without blocking events from firing
    sleep 3; 
    

=for test_synopsis
use 5.10.0;

=head1 DESCRIPTION

Strictly speaking, these don't actually (currently) require Coro and are
implemented purely using AnyEvent.  However, they're likely only useful in
such a situation where you want to be able to program procedurally.

If you are using Coro, then sleep is probably better gotten from
L<Coro::AnyEvent>.

The helpers in this module are exported by L<Sub::Exporter>. 

=head1 SEE ALSO 

ONE
ONE::Timer
ONE::Collect

=head1 RELATED

=over

=item L<Coro::AnyEvent>

=back


# ABSTRACT: IO wrappers for ONE
package ONE::IO;
use strict;
use warnings;
use MooseX::Event;
use Scalar::Util qw( weaken );
use AnyEvent;

=attr IO $.fh is ro
This stores the filehandle we're providing events for
=cut
has 'fh' => (is=>'ro', required=>1);

has '_readable' => (is=>'rw', init_arg=>undef);
has '_writable' => (is=>'rw', init_arg=>undef);

=event readable( IO $fh )
Triggered whenever the file handle has become readable
=cut
has_event 'readable';

=event writable( IO $fh )
Triggered whenever the file handle has become writable
=cut
has_event 'writable';

sub BUILD {
    my $self = shift;
    my $readable = $self->metaevent("readable");
    $readable->on( first_listener => event {
        $self->_readable( AE::io $self->fh, 0, sub { $self->emit('readable', $self->fh) } );
    } );
    $readable->on( no_listeners => event {
        $self->_writable( undef );
    } );
    my $writable = $self->metaevent("writable");
    $writable->on( first_listener => event {
        $self->_writable( AE::io $self->fh, 1, sub { $self->emit('writable', $self->fh) } );
    } );
    $writable->on( no_listeners => event {
        $self->_writable( undef );
    } );
}

1;

=head1 SYNOPSIS

    use ONE::IO;

    # Wait until STDIN is readable, then read one line
    my $stdin = ONE::IO->new( fh=>\*STDIN );
    $stdin->once( readable => event {
        my $self = shift;
        my( $fh ) = @_;
        chomp( my $input = <$fh>);
        warn "Read: $input\n";
    });

=head1 DESCRIPTION

This provides very simple IO filehandle watching, wrapping AnyEvent's AE::io
functionality.  Typically you wouldn't use this directly and would use a
higher level object that provides more semantics, like buffering and error
handling.

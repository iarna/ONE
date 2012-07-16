# ABSTRACT: Capture
package ONE::Capture;
use AnyEvent::Capture ();

sub import {
    my $class = shift;
    my $caller = caller;
    eval "package $caller; AnyEvent::Capture->import(\@_);";
    Carp::croak($@) if $@;
}

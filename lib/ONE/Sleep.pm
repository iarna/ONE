# ABSTRACT: Sleep
package ONE::Sleep;
use AnyEvent::Sleep ();

sub import {
    my $class = shift;
    my $caller = caller;
    eval "package $caller; AnyEvent::Sleep->import(\@_);";
    Carp::croak($@) if $@;
}

1;

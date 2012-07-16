# ABSTRACT: Collect
package ONE::Collect;
use AnyEvent::Collect ();

sub import {
    my $class = shift;
    my $caller = caller;
    eval "package $caller; AnyEvent::Collect->import(\@_);";
    Carp::croak($@) if $@;
}

1;

use strict;
use warnings;
BEGIN {
    require Test::More;
    eval q{ use Coro };
    if ( $@ ) {
        Test::More->import( skip_all => $@ );
    }
    else {
        Test::More->import( tests => 6 );
    }
}
use ONE qw( Timer );

my $started = 0; 
my $finished = 0;
ONE->on( start => event { $started ++ } );
ONE->on( stop  => event { $finished ++ } );

my $idlecount = 0;
my $idle = ONE->on( idle => event { $idlecount ++ } );

# We're also testing loop and stop here
# And just to prove we can, we cede here, this is safe because under Coro,
# event listeners run in their own threads
ONE::Timer->every( 0.1 => event { cede; ONE->stop } );

ONE->loop;

is( $started, 1, "The start event triggered" );
is( $finished, 1, "The stop event triggered" );

cmp_ok( $idlecount, '>', 100, "The idle counter ticked a reasonable number of times." );

ONE->remove_listener( idle =>$idle );

$idlecount = 0;

ONE->loop; # The every trigger we setup earlier will continue to fire, stopping us again.

is( $idlecount, 0, "The idle counter did not tick after we removed it" );

is( $started, 2, "The start event triggered (again)" );
is( $finished, 2, "The stop event triggered (again)" );

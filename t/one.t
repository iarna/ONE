use strict;
use warnings;
use Test::More tests => 8;
use ONE qw( Timer Signal Collect Sleep );

my $started = 0; 
my $finished = 0;
ONE->on( start => event { $started ++ } );
ONE->on( stop  => event { $finished ++ } );

my $idlecount = 0;
my $idle = ONE->on( idle => event { $idlecount ++ } );

# We're also testing loop and stop here
ONE::Timer->after( 0.1 => event { ONE->stop } );
ONE->loop;

cmp_ok( $idlecount, '>', 100, "The idle counter ticked a reasonable number of times." );

ONE->remove_listener( idle =>$idle );

$idlecount = 0;

sleep .1;

is( $idlecount, 0, "The idle counter did not tick after we removed it" );

is( $started, 1, "The start event triggered" );
is( $finished, 1, "The stop event triggered" );

my $alarm = 0;
ONE::Signal->on( ALRM => event { $alarm ++ } );
alarm(1);
sleep 1.1;
alarm(0);

is( $alarm, 1, "The alarm signal triggered" );

my $cnt = 0;

collect {
    ONE::Timer->every( 0.2 => event { $cnt ++ } );
    ONE::Timer->every( 0.5 => event { $cnt += 10 } );
};
is( $cnt, 12, "We collected three event triggers of the right kinds" );

my $postponed = 0;
collect {
    ONE::Timer->after( 0 => event {} );
    ONE->next(event { $postponed = 1 });
    is( $postponed, 0, "Our postponed code hasn't been excuted prior to entering the event loop" );
};
is( $postponed, 1, "Our postponed code was executed" );

done_testing( 8 );

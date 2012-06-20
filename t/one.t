use strict;
use warnings;
use Test::More tests => 6;
use ONE qw( Timer Signal Coro=sleep:collect );

my $started = 0; 
my $finished = 0;
ONE->on( start => sub { $started ++ } );
ONE->on( stop  => sub { $finished ++ } );

my $idlecount = 0;
my $idle = ONE->on( idle => sub { $idlecount ++ } );

# We're also testing loop and stop here
ONE::Timer->after( 0.1 => sub { ONE->stop } );
ONE->loop;

cmp_ok( $idlecount, '>', 100, "The idle counter ticked a reasonable number of times." );

ONE->remove_listener( idle =>$idle );

$idlecount = 0;

sleep .1;

is( $idlecount, 0, "The idle counter did not tick after we removed it" );

is( $started, 1, "The start event triggered" );
is( $finished, 1, "The stop event triggered" );

my $alarm = 0;
ONE::Signal->on( ALRM => sub { $alarm ++ } );
alarm(1);
sleep 1.1;
alarm(0);

is( $alarm, 1, "The alarm signal triggered" );

my $cnt = 0;

collect {
    ONE::Timer->every( 0.2 => sub { $cnt ++ } );
    ONE::Timer->every( 0.5 => sub { $cnt += 10 } );
};
is( $cnt, 12, "We collected three event triggers of the right kinds" );


done_testing( 6 );
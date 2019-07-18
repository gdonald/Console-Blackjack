use v6.d;
use lib 'lib';
use Game;

sub MAIN {
  srand time;
  Game.new.run;
}

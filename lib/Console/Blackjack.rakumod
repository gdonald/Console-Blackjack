
unit module Console::Blackjack;

use Console::Blackjack::Shoe;
use Console::Blackjack::DealerHand;
use Console::Blackjack::PlayerHand;
use Console::Blackjack::Hand;
use Console::Blackjack::Card;

class Game is export {
  has Str $!save-file;
  has Rat $!starting-money;
  has Rat $!min-bet;
  has Rat $!max-bet;
  has IO::Handle $!tty;
  has Shoe $.shoe;
  has DealerHand $!dealer-hand;
  has PlayerHand @.player-hands;
  has Int $.current-player-hand;
  has Rat $!current-bet;
  has Rat $.money is rw;
  has Bool $!quitting;

  submethod BUILD {
    $!quitting = False;
    $!save-file = 'bj.txt';
    $!min-bet = 5.0;
    $!max-bet = 1000000.0;
    $!current-bet = 5.0;
    $!starting-money = 100.0;
    $!money = $!starting-money;
    Shoe.num-decks = 8;
    Shoe.deck-type = 1;
    Card.face-type = 1;

    self.load-game;

    $!dealer-hand = DealerHand.new(game => self);
    $!current-player-hand = 0;
    @!player-hands = [];
    $!shoe = Shoe.new;
  }

  method run {
    while !$!quitting { self.deal-new-hand; }
  }

  method read-one-char(--> Str) {
    $!tty = "/dev/tty".IO.open;
    shell "stty raw -echo min 1 time 1";
    my Str $c = $!tty.read(1).decode('utf-8');
    shell "stty sane";
    $c;
  }

  method all-bets(--> Rat) {
    [+] @!player-hands>>.bet
  }

  method more-hands-to-play(--> Bool) {
    $!current-player-hand < @!player-hands.elems - 1;
  }

  method need-to-play-dealer-hand(--> Bool) {
    for @!player-hands -> $h {
      return True if !($h.is-busted || $h.is-blackjack);
    }

    False;
  }

  method split-current-hand {
    my PlayerHand $current-hand = @!player-hands[$!current-player-hand];

    unless $current-hand.can-split {
      self.draw-hands;
      $current-hand.get-action;
      return;
    }

    @!player-hands.push(PlayerHand.new(game => self, bet => $!current-bet));

    my Int $x = @!player-hands.elems - 1;

    while $x > $!current-player-hand {
      my Hand $h = @!player-hands[$x - 1];
      @!player-hands[$x].cards = $h.cards;
      --$x;
    }

    my PlayerHand $this-hand = @!player-hands[$!current-player-hand];
    my PlayerHand $split-hand = @!player-hands[$!current-player-hand + 1];

    $split-hand.cards = [$this-hand.cards.pop];
    $this-hand.cards.push($!shoe.get-next-card);

    if $this-hand.is-done {
      $this-hand.process;
      return;
    }

    self.draw-hands;
    @!player-hands[$!current-player-hand].get-action;
  }

  method play-more-hands {
    ++$!current-player-hand;
    my PlayerHand $player-hand = @!player-hands[$!current-player-hand];

    $player-hand.deal-card;
    if $player-hand.is-done {
      $player-hand.process;
      return;
    }

    self.draw-hands;
    $player-hand.get-action;
  }

  method play-dealer-hand {
    $!dealer-hand.hide-down-card = False if $!dealer-hand.is-blackjack;

    if !self.need-to-play-dealer-hand {
      $!dealer-hand.played = True;
      self.pay-hands;
      return;
    }

    $!dealer-hand.hide-down-card = False;

    my Int $soft-count = $!dealer-hand.get-value(Hand::CountMethod::Soft);
    my Int $hard-count = $!dealer-hand.get-value(Hand::CountMethod::Hard);

    while $soft-count < 18 && $hard-count < 17 {
      $!dealer-hand.deal-card;
      $soft-count = $!dealer-hand.get-value(Hand::CountMethod::Soft);
      $hard-count = $!dealer-hand.get-value(Hand::CountMethod::Hard);
    }

    $!dealer-hand.played = True;
    self.pay-hands;
  }

  method deal-new-hand {
    $!shoe = Shoe.new if $!shoe.need-to-shuffle;
    @!player-hands = [];
    PlayerHand.total-player-hands = 0;

    my PlayerHand $player-hand = PlayerHand.new(game => self, bet => $!current-bet);
    @!player-hands.push($player-hand);
    $!current-player-hand = 0;

    $!dealer-hand = DealerHand.new(game => self);

    $player-hand.deal-card;
    $!dealer-hand.deal-card;
    $player-hand.deal-card;
    $!dealer-hand.deal-card;

    if $!dealer-hand.up-card-is-ace {
      self.draw-hands;
      self.ask-insurance;
      return;
    }

    $!dealer-hand.hide-down-card = False if $!dealer-hand.is-done;
    $!dealer-hand.hide-down-card = False if  $player-hand.is-done;

    if $!dealer-hand.is-done || $player-hand.is-done {
      self.pay-hands;
      self.draw-hands;
      self.draw-player-bet-options;
      return;
    }

    self.draw-hands;
    $player-hand.get-action;
    self.save-game;
  }

  method draw-hands {
    self.clear;

    say "\n Dealer:";
    $!dealer-hand.draw;
    print "\n\n Player \$";
    print sprintf('%.2f', $!money);
    print "\n";

    for @!player-hands.kv -> $k, $h {
      $h.draw($k);
    }
  }

  method ask-insurance {
    my Str $opts = ' Insurance?  (Y) Yes  (N) No';
    say $opts;

    my Bool $br = False;
    my Str $c;

    loop {
      $c = self.read-one-char;

      given $c {
        when 'y' { $br = True; self.insure-hand;  }
        when 'n' { $br = True; self.no-insurance; }
        default {
          $br = True;
          self.clear;
          self.draw-hands;
          self.ask-insurance;
        }
      }

      last if $br
    }
  }

  method insure-hand {
    my PlayerHand $h = @!player-hands[$!current-player-hand];

    $h.bet /= 2;
    $h.played = True;
    $h.payed = True;
    $h.status = Hand::Status::Lost;
    $!money -= $h.bet;

    self.draw-hands;
    self.draw-player-bet-options;
  }

  method no-insurance {
    if $!dealer-hand.is-blackjack {
      $!dealer-hand.hide-down-card = False;
      $!dealer-hand.played = True;

      self.pay-hands;
      self.draw-hands;
      self.draw-player-bet-options;
      return;
    }

    my PlayerHand $h = @!player-hands[$!current-player-hand];

    if $h.is-done {
      self.play-dealer-hand;
      self.draw-hands;
      self.draw-player-bet-options;
      return;
    }

    self.draw-hands;
    $h.get-action;
  }

  method pay-hands {
    my Int $dhv = $!dealer-hand.get-value(Hand::CountMethod::Soft);
    my Bool $dhb = $!dealer-hand.is-busted;

    for @!player-hands -> $h {
      next if $h.payed;
      $h.payed = True;

      my Int $phv = $h.get-value(Hand::CountMethod::Soft);

      if $dhb || $phv > $dhv {
        $h.bet *= 1.5 if $h.is-blackjack;
        $!money += $h.bet;
        $h.status = Hand::Status::Won;
      } elsif $phv < $dhv {
        $!money -= $h.bet;
        $h.status = Hand::Status::Lost;
      } else {
        $h.status = Hand::Status::Push
      }
    }

    self.normalize-current-bet;
    self.save-game;
  }

  method draw-player-bet-options {
    say ' (D) Deal Hand  (B) Change Bet  (O) Options  (Q) Quit';

    my Bool $br = False;
    my Str $c;

    loop {
      $c = self.read-one-char;

      given $c {
        when 'd' { $br = True; }
        when 'b' { $br = True; self.get-new-bet; }
        when 'o' { $br = True; self.game-options; }
        when 'q' { $br = True; self.clear; $!quitting = True; }
        default {
          $br = True;
          self.clear;
          self.draw-hands;
          self.draw-player-bet-options;
        }
      }

      last if $br
    }
  }

  method game-options {
    self.clear;
    self.draw-hands;

    say ' (N) Number of Decks  (T) Deck Type  (F) Face Type  (B) Back';

    my Bool $br = False;
    my Str $c;

    loop {
      $c = self.read-one-char;

      given $c {
        when 'n' { $br = True; self.get-new-num-decks; }
        when 't' { $br = True; self.get-new-deck-type; }
        when 'f' { $br = True; self.get-new-face-type; }
        when 'b' {
          $br = True;
          self.clear;
          self.draw-hands;
          self.draw-player-bet-options;
        }
        default {
          $br = True;
          self.clear;
          self.draw-hands;
          self.game-options;
        }
      }

      last if $br
    }
  }

  method get-new-face-type {
    self.clear;
    self.draw-hands;

    say ' (1) A♠  (2) 🂡';

    my Bool $br = False;
    my Str $c;

    loop {
      $c = self.read-one-char;

      given $c {
        when 1..2 { $br = True; }
        default {
          $br = True;
          self.clear;
          self.draw-hands;
          self.get-new-face-type;
        }
      }

      if $br {
        Card.face-type = $c;
        self.save-game;
        self.clear;
        self.draw-hands;
        self.draw-player-bet-options;
        last;
      }
    }
  }

  method get-new-deck-type {
    self.clear;
    self.draw-hands;

    say ' (1) Regular  (2) Aces  (3) Jacks  (4) Aces & Jacks  (5) Sevens  (6) Eights';

    my Bool $br = False;
    my Str $c;

    loop {
      $c = self.read-one-char;

      given $c {
        when 1..6 { $br = True; }
        default {
          $br = True;
          self.clear;
          self.draw-hands;
          self.get-new-deck-type;
        }
      }

      if $br {
        Shoe.num-decks = 8 unless $c == 1;
        Shoe.deck-type = $c;
        $!shoe = Shoe.new;
        self.save-game;
        self.clear;
        self.draw-hands;
        self.draw-player-bet-options;
        last;
      }
    }
  }

  method get-new-num-decks {
    self.clear;
    self.draw-hands;

    my Str $opts = '  Number Of Decks: ';
    $opts ~= Shoe.num-decks;
    $opts ~= "\n";
    $opts ~= '  Enter New Number Of Decks: ';

    my Int $tmp = prompt $opts;

    $tmp = 1 if $tmp < 1;
    $tmp = 8 if $tmp > 8;

    Shoe.num-decks = $tmp;
    $!shoe = Shoe.new;
    self.save-game;
    self.game-options;
  }

  method get-new-bet {
    self.clear;
    self.draw-hands;

    my Str $opts = '  Current Bet: $';
    $opts ~= $!current-bet;
    $opts ~= "\n";
    $opts ~= '  Enter New Bet: $';

    my Str $bet = prompt $opts;
    $!current-bet = $bet.Rat;

    self.normalize-current-bet;
    self.deal-new-hand;
  }

  method normalize-current-bet {
    $!current-bet = $!min-bet if $!current-bet < $!min-bet;
    $!current-bet = $!max-bet if $!current-bet > $!max-bet;
    $!current-bet = $!money   if $!current-bet > $!money;
  }

  method save-game {
    if (my $fh = open $!save-file, :w) {
      $fh.print(Shoe.num-decks | '|' | Shoe.deck-type | '|' | Card.face-type | "|$!money|$!current-bet");
      $fh.close;
    }
  }

  method load-game {
    if (my $fh = open $!save-file, :r) {
      my $contents = $fh.slurp-rest;
      $fh.close;

      my Str @a = $contents.split('|');
      Shoe.num-decks = @a[0].Int;
      Shoe.deck-type = @a[1].Int;
      Card.face-type = @a[2].Int;
      $!money        = @a[3].Rat;
      $!current-bet  = @a[4].Rat;
    }

    $!money = $!starting-money if $!money <= $!min-bet;
  }

  method clear {
    shell 'export TERM=linux; clear';
  }
}


unit class Console::Blackjack::PlayerHand;

use Console::Blackjack::Hand;

class PlayerHand is Hand is export {
  my Int $.max-player-hands = 7;
  my Int $.total-player-hands = 0;

  has $!game;
  has Rat $.bet is rw;
  has Hand::Status $.status is rw;
  has Bool $.payed is rw;

  submethod BUILD(:$!game, :$!bet) {
    ++PlayerHand.total-player-hands;
    $!status = Hand::Status::Unknown;
    $!payed = False;
  }

  method get-action {
    my Str $opts = " ";
    $opts ~= "(H) Hit  "    if self.can-hit;
    $opts ~= "(S) Stand  "  if self.can-stand;
    $opts ~= "(P) Split  "  if self.can-split;
    $opts ~= "(D) Double  " if self.can-dbl;
    say $opts;

    my Bool $br = False;
    my Str $c;

    loop {
      $c = $!game.read-one-char;

      given $c {
        when 'h' { if self.can-hit()   { $br = True;
        self.hit; } }
        when 's' { if self.can-stand() { $br = True;
        self.stand; } }
        when 'p' { if self.can-split() { $br = True;
        $!game.split-current-hand; } }
        when 'd' { if self.can-dbl()   { $br = True;
        self.dbl; } }
        default {
          $br = True;
          $!game.clear;
          $!game.draw-hands;
          self.get-action;
        }
      }

      last if $br;
    }
  }

  method hit {
    self.deal-card;

    if self.is-done {
      self.process;
      return;
    }

    $!game.draw-hands;
    $!game.player-hands[$!game.current-player-hand].get-action;
  }

  method stand {
    $.stood = True;
    $.played = True;

    if $!game.more-hands-to-play {
      $!game.play-more-hands;
      return;
    }

    $!game.play-dealer-hand;
    $!game.draw-hands;
    $!game.draw-player-bet-options;
  }

  method dbl {
    self.deal-card;
    $.played = True;
    $!bet *= 2;

    self.process if self.is-done;
  }

  method can-split(--> Bool) {
    return False if $.stood || PlayerHand.total-player-hands >= PlayerHand.max-player-hands;
    return False if $!game.money < $!game.all-bets + $!bet;
    return True  if @.cards.elems == 2 && @.cards[0].value == @.cards[1].value;
    False;
  }

  method can-dbl(--> Bool) {
    return False if $!game.money < $!game.all-bets + $!bet;
    return False if $.stood || @.cards.elems != 2 || self.is-busted || self.is-blackjack;
    True;
  }

  method can-stand(--> Bool) {
    !($.stood || self.is-busted || self.is-blackjack);
  }

  method can-hit(--> Bool) {
    !($.played || $.stood || 21 == self.get-value(Hand::CountMethod::Hard) || self.is-busted || self.is-blackjack);
  }

  method is-done(--> Bool) {
    if $.played || $.stood || self.is-blackjack || self.is-busted || 21 == self.get-value(Hand::CountMethod::Soft) || 21 == self.get-value(Hand::CountMethod::Hard) {
      $.played = True;

      if !$!payed {
        if self.is-busted {
          $!payed = True;
          $!status = Hand::Status::Lost;
          $!game.money -= $!bet;
        }
      }

      return True;
    }

    False;
  }

  method process {
    if $!game.more-hands-to-play {
      $!game.play-more-hands;
      return;
    }

    $!game.play-dealer-hand;
    $!game.draw-hands;
    $!game.draw-player-bet-options;
  }

  method get-value(Hand::CountMethod $count-method, --> Int) {
    my Int $v = 0;
    my Int $total = 0;

    for @.cards.kv -> $k, $card {
      my Int $tmp_v = $card.value + 1;
      $v = $tmp_v > 9 ?? 10 !! $tmp_v;
      $v = 11 if $count-method == Hand::CountMethod::Soft && $v == 1 && $total < 11;
      $total += $v;
    }

    return self.get-value(Hand::CountMethod::Hard) if $count-method == Hand::CountMethod::Soft && $total > 21;
    $total;
  }

  method draw(Int $index) {
    print ' ';

    for @.cards -> $card {
      print $card.draw;
      print ' ';
    }

    print ' ⇒  ';
    print self.get-value(Hand::CountMethod::Soft);
    print '  ';

    if $!status == Hand::Status::Lost {
      print '-';
    } else {
      print '+';
    }

    print '$';
    print sprintf('%.2f', $!bet);

    if !$.played && $index == $!game.current-player-hand {
      print ' ⇐';
    }

    print '  ';

    if $!status == Hand::Status::Lost {
      print self.is-busted ?? 'Busted!' !! 'Lose!';
    } elsif $!status == Hand::Status::Won {
      print self.is-blackjack ?? 'Blackjack!' !! 'Won!';
    } elsif $!status == Hand::Status::Push {
      print 'Push';
    }

    say "\n";
  }
}

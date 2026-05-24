use lib 'lib';
use BDD::Behave;
use Console::Blackjack;
use Console::Blackjack::Shoe;
use Console::Blackjack::PlayerHand;
use Console::Blackjack::DealerHand;
use Console::Blackjack::Hand;
use Console::Blackjack::Card;

sub dealer-of($g) {
  $g.^attributes.first(*.name eq '$!dealer-hand').get_value($g);
}

sub install-fresh-dealer($g) {
  my $dh = DealerHand.new(game => $g);
  $g.^attributes.first(*.name eq '$!dealer-hand').set_value($g, $dh);
  $dh;
}

describe 'Console::Blackjack::Game', {
  let(:tmpdir, { ($*TMPDIR ~ '/console-blackjack-game-spec-' ~ $*PID).IO });
  let(:orig-cwd, { $*CWD });

  before-each {
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    $tmp.mkdir unless $tmp.e;
    chdir $tmp;
    PlayerHand.total-player-hands = 0;
    Card.face-type = 1;
    Shoe.num-decks = 8;
    Shoe.deck-type = 1;
  }

  after-each {
    chdir $*LET-RUNTIME.value('orig-cwd');
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    if $tmp.e {
      for $tmp.dir -> $f { $f.unlink if $f.f; }
      $tmp.rmdir;
    }
    Shoe.num-decks = 8;
    Shoe.deck-type = 1;
    Card.face-type = 1;
  }

  describe 'BUILD defaults', {
    it 'Game.new returns a Game', {
      expect(Game.new).to.be-a(Game);
    }

    it 'sets starting money to 100.0', {
      expect(Game.new.money).to.be(100.0);
    }

    it 'creates a shoe', {
      expect(Game.new.shoe).to.be-a(Shoe);
    }

    it 'current-player-hand starts at 0', {
      expect(Game.new.current-player-hand).to.be(0);
    }

    it 'player-hands starts empty', {
      expect(Game.new.player-hands.elems).to.be(0);
    }

    it 'sets Shoe.num-decks to 8', {
      Game.new;
      expect(Shoe.num-decks).to.be(8);
    }

    it 'sets Shoe.deck-type to 1', {
      Game.new;
      expect(Shoe.deck-type).to.be(1);
    }

    it 'sets Card.face-type to 1', {
      Game.new;
      expect(Card.face-type).to.be(1);
    }
  }

  describe 'all-bets', {
    it 'sums bets across player hands', {
      my $g = Game.new;
      $g.player-hands.push(PlayerHand.new(game => $g, bet => 5.0));
      $g.player-hands.push(PlayerHand.new(game => $g, bet => 7.5));
      expect($g.all-bets).to.be(12.5);
    }
  }

  describe 'more-hands-to-play', {
    it 'is False when on the only hand', {
      my $g = Game.new;
      $g.player-hands.push(PlayerHand.new(game => $g, bet => 5.0));
      expect($g.more-hands-to-play).to.be-falsy;
    }

    it 'is True when more hands remain', {
      my $g = Game.new;
      $g.player-hands.push(PlayerHand.new(game => $g, bet => 5.0));
      $g.player-hands.push(PlayerHand.new(game => $g, bet => 5.0));
      expect($g.more-hands-to-play).to.be-truthy;
    }
  }

  describe 'need-to-play-dealer-hand', {
    it 'is True when at least one hand is active', {
      my $g = Game.new;
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($h);
      expect($g.need-to-play-dealer-hand).to.be-truthy;
    }

    it 'is False when every hand is busted or blackjack', {
      my $g = Game.new;
      my $bust = PlayerHand.new(game => $g, bet => 5.0);
      $bust.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      my $bj = PlayerHand.new(game => $g, bet => 5.0);
      $bj.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $g.player-hands.push($bust);
      $g.player-hands.push($bj);
      expect($g.need-to-play-dealer-hand).to.be-falsy;
    }
  }

  describe 'save-game / load-game', {
    it 'save-game writes bj.txt', {
      my $g = Game.new;
      $g.save-game;
      expect('bj.txt'.IO.e).to.be-truthy;
    }

    it 'save-game writes pipe-delimited fields', {
      my $g = Game.new;
      $g.money = 250.0;
      Shoe.num-decks = 4;
      Shoe.deck-type = 2;
      Card.face-type = 2;
      $g.save-game;
      expect('bj.txt'.IO.slurp).to.be('4|2|2|250|5');
    }

    it 'load-game restores num-decks', {
      'bj.txt'.IO.spurt('4|2|2|250|5');
      Shoe.num-decks = 1;
      my $g = Game.new;
      expect(Shoe.num-decks).to.be(4);
    }

    it 'load-game restores deck-type', {
      'bj.txt'.IO.spurt('4|2|2|250|5');
      Shoe.deck-type = 1;
      my $g = Game.new;
      expect(Shoe.deck-type).to.be(2);
    }

    it 'load-game restores face-type', {
      'bj.txt'.IO.spurt('4|2|2|250|5');
      Card.face-type = 1;
      my $g = Game.new;
      expect(Card.face-type).to.be(2);
    }

    it 'load-game resets money to starting when at or below min-bet', {
      'bj.txt'.IO.spurt('4|1|1|1|5');
      my $g = Game.new;
      expect($g.money).to.be(100.0);
    }
  }

  describe 'pay-hands', {
    it 'marks player Won when dealer busts', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $g.player-hands.push($h);
      $g.pay-hands;
      expect($h.status).to.be(Hand::Status::Won);
    }

    it 'credits bet when dealer busts', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $g.player-hands.push($h);
      my $start = $g.money;
      $g.pay-hands;
      expect($g.money).to.be($start + 10.0);
    }

    it 'marks the hand paid', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $g.player-hands.push($h);
      $g.pay-hands;
      expect($h.paid).to.be-truthy;
    }

    it 'marks blackjack Won', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 7, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $g.player-hands.push($h);
      $g.pay-hands;
      expect($h.status).to.be(Hand::Status::Won);
    }

    it 'pays blackjack at 1.5x', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 7, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $g.player-hands.push($h);
      my $start = $g.money;
      $g.pay-hands;
      expect($g.money).to.be($start + 15.0);
    }

    it 'marks loss when player < dealer', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $g.player-hands.push($h);
      $g.pay-hands;
      expect($h.status).to.be(Hand::Status::Lost);
    }

    it 'deducts bet on loss', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $g.player-hands.push($h);
      my $start = $g.money;
      $g.pay-hands;
      expect($g.money).to.be($start - 10.0);
    }

    it 'marks Push when player == dealer', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 9, suit => 1), Card.new(value => 9, suit => 2)];
      $g.player-hands.push($h);
      $g.pay-hands;
      expect($h.status).to.be(Hand::Status::Push);
    }

    it 'leaves money unchanged on Push', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 9, suit => 1), Card.new(value => 9, suit => 2)];
      $g.player-hands.push($h);
      my $start = $g.money;
      $g.pay-hands;
      expect($g.money).to.be($start);
    }

    it 'does not change status of an already-paid hand', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $h.paid = True;
      $h.status = Hand::Status::Won;
      $g.player-hands.push($h);
      $g.pay-hands;
      expect($h.status).to.be(Hand::Status::Won);
    }

    it 'does not touch money for an already-paid hand', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 0)];
      $h.paid = True;
      $g.player-hands.push($h);
      my $start = $g.money;
      $g.pay-hands;
      expect($g.money).to.be($start);
    }
  }

  describe 'play-dealer-hand', {
    it 'marks dealer played when no need to play', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 5, suit => 0), Card.new(value => 5, suit => 0)];
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $g.player-hands.push($h);
      $g.play-dealer-hand;
      expect($dealer.played).to.be-truthy;
    }

    it 'does not deal extra cards when no need to play', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 5, suit => 0), Card.new(value => 5, suit => 0)];
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $g.player-hands.push($h);
      $g.play-dealer-hand;
      expect($dealer.cards.elems).to.be(2);
    }

    it 'reveals the down card on dealer blackjack', {
      my $g = Game.new;
      my $dealer = dealer-of($g);
      $dealer.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $dealer.hide-down-card = True;
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $g.player-hands.push($h);
      $g.play-dealer-hand;
      expect($dealer.hide-down-card).to.be-falsy;
    }

    it 'deals additional cards when the dealer must hit', {
      my $g = Game.new;
      my $dealer = install-fresh-dealer($g);
      $dealer.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($h);
      $g.play-dealer-hand;
      expect($dealer.cards.elems > 2).to.be-truthy;
    }

    it 'stops at a valid stand value', {
      my $g = Game.new;
      my $dealer = install-fresh-dealer($g);
      $dealer.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($h);
      $g.play-dealer-hand;
      expect($dealer.get-value(Hand::CountMethod::Soft) >= 17).to.be-truthy;
    }

    it 'marks dealer played after hitting', {
      my $g = Game.new;
      my $dealer = install-fresh-dealer($g);
      $dealer.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $dealer.hide-down-card = False;
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($h);
      $g.play-dealer-hand;
      expect($dealer.played).to.be-truthy;
    }
  }

  describe 'normalize-current-bet', {
    it 'clamps below min-bet up to 5', {
      'bj.txt'.IO.spurt('8|1|1|100|1');
      my $g = Game.new;
      $g.pay-hands;
      expect('bj.txt'.IO.slurp.split('|')[4]).to.be('5');
    }

    it 'clamps above max-bet down to 1000000', {
      'bj.txt'.IO.spurt('8|1|1|2000000|1500000');
      my $g = Game.new;
      $g.pay-hands;
      expect('bj.txt'.IO.slurp.split('|')[4]).to.be('1000000');
    }

    it 'clamps above money down to money', {
      'bj.txt'.IO.spurt('8|1|1|100|500');
      my $g = Game.new;
      $g.pay-hands;
      expect('bj.txt'.IO.slurp.split('|')[4]).to.be('100');
    }
  }
}

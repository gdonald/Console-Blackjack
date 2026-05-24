use lib 'lib';
use BDD::Behave;
use Console::Blackjack;
use Console::Blackjack::Hand;
use Console::Blackjack::PlayerHand;
use Console::Blackjack::Card;

sub fresh-game(Rat :$money = 100.0 --> Game) {
  PlayerHand.total-player-hands = 0;
  my $g = Game.new;
  $g.money = $money;
  $g;
}

sub captured-out(&block --> Str) {
  my $out = '';
  my $*OUT = class {
    method print(*@a) { $out ~= @a.join; }
    method say(*@a)   { $out ~= @a.join ~ "\n"; }
    method flush      {}
  }.new;
  block();
  $out;
}

describe 'Console::Blackjack::PlayerHand', {
  let(:tmpdir, { ($*TMPDIR ~ '/console-blackjack-player-spec-' ~ $*PID).IO });
  let(:orig-cwd, { $*CWD });

  before-each {
    $*LET-RUNTIME.value('orig-cwd');
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    $tmp.mkdir unless $tmp.e;
    chdir $tmp;
    Card.face-type = 1;
  }

  after-each {
    chdir $*LET-RUNTIME.value('orig-cwd');
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    if $tmp.e {
      for $tmp.dir -> $f { $f.unlink if $f.f; }
      $tmp.rmdir;
    }
  }

  describe 'construction', {
    it 'returns a PlayerHand', {
      expect(PlayerHand.new(game => fresh-game, bet => 5.0)).to.be-a(PlayerHand);
    }

    it 'is a Hand', {
      expect(PlayerHand.new(game => fresh-game, bet => 5.0)).to.be-a(Hand);
    }

    it 'stores the bet', {
      expect(PlayerHand.new(game => fresh-game, bet => 5.0).bet).to.be(5.0);
    }

    it 'defaults status to Unknown', {
      expect(PlayerHand.new(game => fresh-game, bet => 5.0).status)
        .to.be(Hand::Status::Unknown);
    }

    it 'defaults paid to False', {
      expect(PlayerHand.new(game => fresh-game, bet => 5.0).paid).to.be-falsy;
    }

    it 'BUILD increments total-player-hands', {
      PlayerHand.total-player-hands = 0;
      my $g = fresh-game;
      PlayerHand.new(game => $g, bet => 5.0);
      PlayerHand.new(game => $g, bet => 5.0);
      expect(PlayerHand.total-player-hands).to.be(2);
    }

    it 'exposes max-player-hands of 7', {
      expect(PlayerHand.max-player-hands).to.be(7);
    }
  }

  describe 'get-value', {
    it 'sums simple cards (5 + 8 = 13)', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 7, suit => 0)];
      expect($h.get-value(Hand::CountMethod::Soft)).to.be(13);
    }

    it 'Ace + 6 Soft = 17', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.get-value(Hand::CountMethod::Soft)).to.be(17);
    }

    it 'Ace + 6 Hard = 7', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.get-value(Hand::CountMethod::Hard)).to.be(7);
    }

    it 'Soft falls back to Hard when total > 21', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [
        Card.new(value => 0, suit => 0),
        Card.new(value => 5, suit => 0),
        Card.new(value => 8, suit => 0),
      ];
      expect($h.get-value(Hand::CountMethod::Soft)).to.be(16);
    }

    it 'face cards count as 10 (Jack + Queen = 20)', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 10, suit => 0), Card.new(value => 11, suit => 0)];
      expect($h.get-value(Hand::CountMethod::Soft)).to.be(20);
    }
  }

  describe 'is-busted', {
    it 'is True for three tens', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
      ];
      expect($h.is-busted).to.be-truthy;
    }
  }

  describe 'is-blackjack', {
    it 'is True for Ace + King', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      expect($h.is-blackjack).to.be-truthy;
    }
  }

  describe 'can-hit', {
    it 'is True for a regular two-card non-21 hand', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.can-hit).to.be-truthy;
    }

    it 'is False once played', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      expect($h.can-hit).to.be-falsy;
    }

    it 'is False once stood', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.stood = True;
      expect($h.can-hit).to.be-falsy;
    }

    it 'is False on blackjack', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      expect($h.can-hit).to.be-falsy;
    }

    it 'is False when busted', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
      ];
      expect($h.can-hit).to.be-falsy;
    }

    it 'is False on hard 21', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [
        Card.new(value => 6, suit => 0),
        Card.new(value => 6, suit => 0),
        Card.new(value => 8, suit => 0),
      ];
      expect($h.can-hit).to.be-falsy;
    }
  }

  describe 'can-stand', {
    it 'is True for a regular active hand', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.can-stand).to.be-truthy;
    }

    it 'is False once stood', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.stood = True;
      expect($h.can-stand).to.be-falsy;
    }

    it 'is False on blackjack', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      expect($h.can-stand).to.be-falsy;
    }

    it 'is False when busted', {
      my $h = PlayerHand.new(game => fresh-game, bet => 5.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
      ];
      expect($h.can-stand).to.be-falsy;
    }
  }

  describe 'can-split', {
    it 'is True for a pair with funds and under max-player-hands', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      expect($h.can-split).to.be-truthy;
    }

    it 'is False when stood', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      $h.stood = True;
      expect($h.can-split).to.be-falsy;
    }

    it 'is False for a non-pair', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 1)];
      expect($h.can-split).to.be-falsy;
    }

    it 'is False for a single-card hand', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0)];
      expect($h.can-split).to.be-falsy;
    }

    it 'is False without enough money', {
      my $g = fresh-game(money => 5.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      expect($h.can-split).to.be-falsy;
    }

    it 'is False at max-player-hands', {
      my $g = fresh-game(money => 100.0);
      PlayerHand.total-player-hands = 7;
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      expect($h.can-split).to.be-falsy;
    }
  }

  describe 'can-dbl', {
    it 'is True with two cards and funds', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.can-dbl).to.be-truthy;
    }

    it 'is False without enough money', {
      my $g = fresh-game(money => 5.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.can-dbl).to.be-falsy;
    }

    it 'is False with three cards', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [
        Card.new(value => 1, suit => 0),
        Card.new(value => 2, suit => 0),
        Card.new(value => 3, suit => 0),
      ];
      expect($h.can-dbl).to.be-falsy;
    }

    it 'is False when stood', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.stood = True;
      expect($h.can-dbl).to.be-falsy;
    }

    it 'is False on blackjack', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      expect($h.can-dbl).to.be-falsy;
    }
  }

  describe 'is-done', {
    it 'is True on blackjack', {
      my $h = PlayerHand.new(game => fresh-game(money => 100.0), bet => 5.0);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      expect($h.is-done).to.be-truthy;
    }

    it 'is True on bust', {
      my $h = PlayerHand.new(game => fresh-game(money => 100.0), bet => 10.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      expect($h.is-done).to.be-truthy;
    }

    it 'busted hand is marked paid', {
      my $h = PlayerHand.new(game => fresh-game(money => 100.0), bet => 10.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $h.is-done;
      expect($h.paid).to.be-truthy;
    }

    it 'busted hand status is Lost', {
      my $h = PlayerHand.new(game => fresh-game(money => 100.0), bet => 10.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $h.is-done;
      expect($h.status).to.be(Hand::Status::Lost);
    }

    it 'busted hand deducts bet from money', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $h.is-done;
      expect($g.money).to.be(90.0);
    }

    it 'is False for a fresh active hand', {
      my $h = PlayerHand.new(game => fresh-game(money => 100.0), bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      expect($h.is-done).to.be-falsy;
    }

    it 'is True when only played is set', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      expect($h.is-done).to.be-truthy;
    }

    it 'is True when only stood is set', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.stood = True;
      expect($h.is-done).to.be-truthy;
    }

    it 'is True for a 3-card 21', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [
        Card.new(value => 6, suit => 0),
        Card.new(value => 6, suit => 0),
        Card.new(value => 7, suit => 0),
      ];
      expect($h.is-done).to.be-truthy;
    }

    describe 'on an already-paid hand', {
      let(:setup, {
        my $g = fresh-game(money => 100.0);
        my $h = PlayerHand.new(game => $g, bet => 7.0);
        $h.cards = [
          Card.new(value => 9, suit => 0),
          Card.new(value => 9, suit => 1),
          Card.new(value => 9, suit => 2),
        ];
        $h.played = True;
        $h.paid   = True;
        $h.status = Hand::Status::Won;
        my $start = $g.money;
        $h.is-done;
        %( :game($g), :hand($h), :start($start) );
      });

      it 'returns True', {
        my %s = $*LET-RUNTIME.value('setup');
        expect(%s<hand>.is-done).to.be-truthy;
      }

      it 'does not overwrite status', {
        expect($*LET-RUNTIME.value('setup')<hand>.status).to.be(Hand::Status::Won);
      }

      it 'does not change money', {
        my %s = $*LET-RUNTIME.value('setup');
        expect(%s<game>.money).to.be(%s<start>);
      }
    }

    it 'does not change money when only played is set', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      $h.is-done;
      expect($g.money).to.be(100.0);
    }
  }

  describe 'draw output', {
    it 'renders the first card', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $h.status = Hand::Status::Won;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('A♠');
    }

    it 'outputs Blackjack! for Won + blackjack', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $h.status = Hand::Status::Won;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('Blackjack!');
    }

    it 'outputs Busted! for Lost + busted', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $g.player-hands.push($h);
      $h.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 1),
        Card.new(value => 9, suit => 2),
      ];
      $h.status = Hand::Status::Lost;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('Busted!');
    }

    it 'outputs Push for Status::Push', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 10.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $h.status = Hand::Status::Push;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('Push');
    }

    it 'outputs Won! for Won + non-blackjack', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $h.status = Hand::Status::Won;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('Won!');
    }

    it 'does not output Blackjack! for non-bj Won', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $h.status = Hand::Status::Won;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out.contains('Blackjack!')).to.be-falsy;
    }

    it 'outputs Lose! for Lost + non-busted', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 1)];
      $h.status = Hand::Status::Lost;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('Lose!');
    }

    it 'does not output Busted! for non-busted Lost', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 7, suit => 0), Card.new(value => 8, suit => 1)];
      $h.status = Hand::Status::Lost;
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out.contains('Busted!')).to.be-falsy;
    }

    it 'Unknown status emits no Won!', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out.contains('Won!')).to.be-falsy;
    }

    it 'Unknown status emits no Lose!', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out.contains('Lose!')).to.be-falsy;
    }

    it 'Unknown status emits no Push', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out.contains('Push')).to.be-falsy;
    }

    it 'Unknown status emits no Blackjack!', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $h.played = True;
      my $out = captured-out(-> { $h.draw(0) });
      expect($out.contains('Blackjack!')).to.be-falsy;
    }

    it 'renders ⇐ on the active hand', {
      my $g = fresh-game(money => 100.0);
      my $h = PlayerHand.new(game => $g, bet => 5.0);
      $g.player-hands.push($h);
      $h.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      my $out = captured-out(-> { $h.draw(0) });
      expect($out).to.include('⇐');
    }
  }
}

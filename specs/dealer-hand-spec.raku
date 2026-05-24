use lib 'lib';
use BDD::Behave;
use Console::Blackjack;
use Console::Blackjack::Hand;
use Console::Blackjack::DealerHand;
use Console::Blackjack::Card;
use Console::Blackjack::PlayerHand;

describe 'Console::Blackjack::DealerHand', {
  let(:tmpdir, { ($*TMPDIR ~ '/console-blackjack-dealer-spec-' ~ $*PID).IO });
  let(:orig-cwd, { $*CWD });

  before-each {
    $*LET-RUNTIME.value('orig-cwd');
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    $tmp.mkdir unless $tmp.e;
    chdir $tmp;
    PlayerHand.total-player-hands = 0;
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
    it 'returns a DealerHand from .new', {
      expect(DealerHand.new(game => Game.new)).to.be-a(DealerHand);
    }

    it 'is a Hand', {
      expect(DealerHand.new(game => Game.new)).to.be-a(Hand);
    }

    it 'defaults hide-down-card to True', {
      expect(DealerHand.new(game => Game.new).hide-down-card).to.be-truthy;
    }
  }

  describe 'up-card-is-ace', {
    it 'is True when the first card is an ace', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      expect($d.up-card-is-ace).to.be-truthy;
    }

    it 'is False when the first card is not an ace', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 5, suit => 0), Card.new(value => 0, suit => 0)];
      expect($d.up-card-is-ace).to.be-falsy;
    }
  }

  describe 'get-value with hidden down card', {
    it 'Soft uses only the up card (Ace soft = 11)', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $d.hide-down-card = True;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(11);
    }

    it 'Hard with Ace up = 1', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $d.hide-down-card = True;
      expect($d.get-value(Hand::CountMethod::Hard)).to.be(1);
    }
  }

  describe 'get-value with revealed down card', {
    it 'Ace + King Soft = 21', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(21);
    }

    it 'Ace + King Hard = 11', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Hard)).to.be(11);
    }

    it 'King + Ten = 20 Soft', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 12, suit => 0), Card.new(value => 9, suit => 0)];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(20);
    }
  }

  describe 'soft falls back to hard when over 21', {
    it 'Ace + 6 + 9 returns 16', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [
        Card.new(value => 0, suit => 0),
        Card.new(value => 5, suit => 0),
        Card.new(value => 8, suit => 0),
      ];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(16);
    }
  }

  describe 'Ace stays soft when total <= 21', {
    it 'Ace + 6 Soft = 17', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(17);
    }

    it 'Ace + 6 Hard = 7', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Hard)).to.be(7);
    }
  }

  describe 'face cards count as 10', {
    it 'Jack + Queen = 20', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 10, suit => 0), Card.new(value => 11, suit => 0)];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(20);
    }
  }

  describe 'busted hand', {
    it '10+10+10 sums to 30 Soft', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
      ];
      $d.hide-down-card = False;
      expect($d.get-value(Hand::CountMethod::Soft)).to.be(30);
    }

    it 'is-busted returns True when value > 21', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
        Card.new(value => 9, suit => 0),
      ];
      $d.hide-down-card = False;
      expect($d.is-busted).to.be-truthy;
    }
  }

  describe 'is-blackjack via inherited Hand method', {
    it 'recognises Ace + Queen as blackjack', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 11, suit => 0)];
      expect($d.is-blackjack).to.be-truthy;
    }
  }

  describe 'played and hide-down-card accessors', {
    it 'played is settable', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.played = True;
      expect($d.played).to.be-truthy;
    }

    it 'hide-down-card is rw', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.hide-down-card = False;
      expect($d.hide-down-card).to.be-falsy;
    }
  }

  describe 'draw output (hidden down card)', {
    let(:rendered, {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $d.hide-down-card = True;
      my $captured = '';
      {
        my $*OUT = class {
          method print(*@a) { $captured ~= @a.join; }
          method say(*@a)   { $captured ~= @a.join ~ "\n"; }
          method flush      {}
        }.new;
        $d.draw;
      }
      $captured;
    });

    it 'renders the up card', {
      expect($*LET-RUNTIME.value('rendered')).to.include('A♠');
    }

    it 'renders ?? for the hidden down card', {
      expect($*LET-RUNTIME.value('rendered')).to.include('??');
    }

    it 'renders the value separator', {
      expect($*LET-RUNTIME.value('rendered')).to.include('⇒');
    }
  }

  describe 'draw output (revealed down card)', {
    it 'renders the down card when revealed', {
      my $g = Game.new;
      my $d = DealerHand.new(game => $g);
      $d.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $d.hide-down-card = False;
      my $captured = '';
      {
        my $*OUT = class {
          method print(*@a) { $captured ~= @a.join; }
          method say(*@a)   { $captured ~= @a.join ~ "\n"; }
          method flush      {}
        }.new;
        $d.draw;
      }
      expect($captured).to.include('K♠');
    }
  }
}

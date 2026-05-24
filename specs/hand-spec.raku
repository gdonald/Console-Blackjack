use lib 'lib';
use BDD::Behave;
use Console::Blackjack;
use Console::Blackjack::Hand;
use Console::Blackjack::Card;
use Console::Blackjack::PlayerHand;

describe 'Console::Blackjack::Hand', {
  let(:tmpdir, { ($*TMPDIR ~ '/console-blackjack-hand-spec-' ~ $*PID).IO });
  let(:orig-cwd, { $*CWD });

  before-each {
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    $tmp.mkdir unless $tmp.e;
    chdir $tmp;
    PlayerHand.total-player-hands = 0;
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
    it 'returns a Hand from .new', {
      my $g = Game.new;
      expect(Hand.new(game => $g)).to.be-a(Hand);
    }
  }

  describe 'base get-value', {
    it 'returns 0 for Soft', {
      my $g = Game.new;
      expect(Hand.new(game => $g).get-value(Hand::CountMethod::Soft)).to.be(0);
    }

    it 'returns 0 for Hard', {
      my $g = Game.new;
      expect(Hand.new(game => $g).get-value(Hand::CountMethod::Hard)).to.be(0);
    }
  }

  describe 'base is-done', {
    it 'returns False', {
      my $g = Game.new;
      expect(Hand.new(game => $g).is-done).to.be-falsy;
    }
  }

  describe 'base is-busted', {
    it 'returns False because get-value is 0', {
      my $g = Game.new;
      expect(Hand.new(game => $g).is-busted).to.be-falsy;
    }
  }

  describe 'is-blackjack', {
    it 'is True for Ace + King', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      expect($h.is-blackjack).to.be-truthy;
    }

    it 'is True for Ten + Ace (order reversed)', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 0, suit => 1)];
      expect($h.is-blackjack).to.be-truthy;
    }

    it 'is False for Ten + Ten', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      expect($h.is-blackjack).to.be-falsy;
    }

    it 'is False for three cards totaling 21', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [
        Card.new(value => 0, suit => 0),
        Card.new(value => 5, suit => 0),
        Card.new(value => 4, suit => 0),
      ];
      expect($h.is-blackjack).to.be-falsy;
    }

    it 'is False for an empty hand', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [];
      expect($h.is-blackjack).to.be-falsy;
    }

    it 'is False for a single-card hand', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [Card.new(value => 0, suit => 0)];
      expect($h.is-blackjack).to.be-falsy;
    }
  }

  describe 'deal-card', {
    it 'adds a card to the hand', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [];
      $h.deal-card;
      expect($h.cards.elems).to.be(1);
    }

    it 'produces a Card', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [];
      $h.deal-card;
      expect($h.cards[0]).to.be-a(Card);
    }

    it 'can be called repeatedly', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.cards = [];
      $h.deal-card for 1..3;
      expect($h.cards.elems).to.be(3);
    }
  }

  describe 'stood / played accessors', {
    it 'stood is settable', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.stood = True;
      expect($h.stood).to.be-truthy;
    }

    it 'played is settable', {
      my $g = Game.new;
      my $h = Hand.new(game => $g);
      $h.played = True;
      expect($h.played).to.be-truthy;
    }
  }
}

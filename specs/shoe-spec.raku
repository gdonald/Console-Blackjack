use BDD::Behave;
use lib 'lib';
use Console::Blackjack::Shoe;
use Console::Blackjack::Card;

describe 'Console::Blackjack::Shoe', {
  describe 'class accessors', {
    before-each {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
    }

    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'num-decks is settable to 1', {
      expect(Shoe.num-decks).to.be(1);
    }

    it 'deck-type is settable to 1', {
      expect(Shoe.deck-type).to.be(1);
    }

    it 'cards-per-deck is 52', {
      expect(Shoe.cards-per-deck).to.be(52);
    }
  }

  describe 'get-total-cards', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'is 52 for one deck', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
      expect(Shoe.new.get-total-cards).to.be(52);
    }

    it 'is 416 for eight decks', {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
      expect(Shoe.new.get-total-cards).to.be(8 * 52);
    }
  }

  describe 'regular shoe (deck-type 1)', {
    let(:cards, {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..52;
      @c;
    });

    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'yields 52 cards', {
      expect($*LET-RUNTIME.value('cards').elems).to.be(52);
    }

    it 'contains 4 aces', {
      expect($*LET-RUNTIME.value('cards').grep({ .is-ace }).elems).to.be(4);
    }

    it 'contains 4 kings', {
      expect($*LET-RUNTIME.value('cards').grep({ .value == 12 }).elems).to.be(4);
    }
  }

  describe 'aces-only shoe (deck-type 2)', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'contains only aces', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 2;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..52;
      expect(@c.grep({ ! .is-ace }).elems).to.be(0);
    }
  }

  describe 'jacks-only shoe (deck-type 3)', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'contains only jacks', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 3;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..52;
      expect(@c.grep({ .value != 10 }).elems).to.be(0);
    }
  }

  describe 'aces-and-jacks shoe (deck-type 4)', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'contains only aces and jacks', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 4;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..52;
      expect(@c.grep({ .value != 0 && .value != 10 }).elems).to.be(0);
    }
  }

  describe 'sevens-only shoe (deck-type 5)', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'contains only sevens', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 5;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..52;
      expect(@c.grep({ .value != 6 }).elems).to.be(0);
    }
  }

  describe 'eights-only shoe (deck-type 6)', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'contains only eights', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 6;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..52;
      expect(@c.grep({ .value != 7 }).elems).to.be(0);
    }
  }

  describe 'get-next-card', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'returns a Card', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
      expect(Shoe.new.get-next-card).to.be-a(Card);
    }
  }

  describe 'need-to-shuffle', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'is True when the shoe is empty', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
      my $s = Shoe.new;
      $s.get-next-card for 1..52;
      expect($s.need-to-shuffle).to.be-truthy;
    }

    it 'is False on a freshly-built shoe', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
      expect(Shoe.new.need-to-shuffle).to.be-falsy;
    }
  }

  describe 'need-to-shuffle thresholds', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    my %threshold = (1 => 80, 2 => 81, 3 => 82, 4 => 84, 5 => 86, 6 => 89, 7 => 92, 8 => 95);

    for %threshold.kv -> $decks, $pct {
      it "triggers True past $pct% used with $decks deck(s)", {
        Shoe.num-decks = $decks.Int;
        Shoe.deck-type = 1;
        my $s = Shoe.new;
        my Int $total   = $decks.Int * 52;
        my Int $to-deal = (($pct + 1) / 100 * $total).Int;
        $s.get-next-card for 1..$to-deal;
        expect($s.need-to-shuffle).to.be-truthy;
      }
    }
  }

  describe 'shuffle randomness', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'produces different orders across fresh shoes', {
      Shoe.num-decks = 1;
      Shoe.deck-type = 1;
      my $a = Shoe.new;
      my $b = Shoe.new;
      my @a = (1..52).map({ $a.get-next-card.value });
      my @b = (1..52).map({ $b.get-next-card.value });
      expect(@a eqv @b).to.be-falsy;
    }
  }

  describe 'multi-deck regular shoe', {
    after-each {
      Shoe.num-decks = 8;
      Shoe.deck-type = 1;
    }

    it 'yields 104 cards for two decks', {
      Shoe.num-decks = 2;
      Shoe.deck-type = 1;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..104;
      expect(@c.elems).to.be(104);
    }

    it 'contains 8 aces for two decks', {
      Shoe.num-decks = 2;
      Shoe.deck-type = 1;
      my $s = Shoe.new;
      my @c;
      @c.push($s.get-next-card) for 1..104;
      expect(@c.grep({ .is-ace }).elems).to.be(8);
    }
  }
}


unit class Console::Blackjack::Shoe;

use Console::Blackjack::Card;

class Shoe is export {
  my Int $.num-decks;
  my Int $.deck-type;
  my Int $.cards-per-deck = 52;
  has Pair @!shuffle-specs;
  has Card @!cards;

  submethod BUILD() {
    @!shuffle-specs = (80 => 1), (81 => 2), (82 => 3), (84 => 4), (86 => 5), (89 => 6), (92 => 7), (95 => 8);
    given Shoe.deck-type {
      when 2 { self.new-aces; }
      when 3 { self.new-jacks; }
      when 4 { self.new-aces-jacks; }
      when 5 { self.new-sevens; }
      when 6 { self.new-eights; }
      default { self.new-regular; }
    }
  }

  method get-total-cards(--> Int) { Shoe.num-decks * Shoe.cards-per-deck; }

  method get-next-card { @!cards.pop; }

  method need-to-shuffle(--> Bool) {
    return True if @!cards.elems == 0;

    my Int $total-cards = self.get-total-cards;
    my Int $cards-dealt = $total-cards - @!cards.elems;
    my Rat $used-cards = ($cards-dealt / $total-cards) * 100.0;

    for 0..7 -> $x {
      my Int $allowed = @!shuffle-specs[$x].key;
      my Int $decks   = @!shuffle-specs[$x].value;
      return True if Shoe.num-decks == $decks && $used-cards > $allowed;
    }

    False;
  }

  method new-regular    { self.new-shoe([0..12]); }
  method new-aces       { self.new-shoe([0]); }
  method new-jacks      { self.new-shoe([10]); }
  method new-aces-jacks { self.new-shoe([0, 10]); }
  method new-sevens     { self.new-shoe([6]); }
  method new-eights     { self.new-shoe([7]); }

  method shuffle { for 0..6 { @!cards = @!cards.pick: *; } }

  method new-shoe(@values) {
    @!cards = [];
    my $total-cards = self.get-total-cards;

    while @!cards.elems < $total-cards {
      for 0..3 -> $suit {
        last if @!cards.elems >= $total-cards;
        for @values -> $value {
          last if @!cards.elems >= $total-cards;
          @!cards.push(Card.new(:$value, :$suit));
        }
      }
    }

    self.shuffle;
  }
}

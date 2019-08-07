
use Console::Blackjack::Card;

class Shoe is export {
  has Pair @!shuffle-specs;
  has Int $!num-decks;
  has Card @!cards;

  submethod BUILD(:$!num-decks) {
    @!shuffle-specs = (80 => 1), (81 => 2), (82 => 3), (84 => 4), (86 => 5), (89 => 6), (92 => 7), (95 => 8);
    self.shuffle;
  }

  method get-next-card {
    @!cards.pop;
  }

  method need-to-shuffle(--> Bool) {
    return True if @!cards.elems == 0;

    my Int $total-cards = $!num-decks * 52;
    my Int $cards-dealt = $total-cards - @!cards.elems;
    my Rat $used-cards = ($cards-dealt / $total-cards) * 100.0;

    for 0..7 -> $x {
      my Int $allowed = @!shuffle-specs[$x].key;
      my Int $decks   = @!shuffle-specs[$x].value;
      return True if $!num-decks == $decks && $used-cards > $allowed;
    }

    False;
  }

  method shuffle {
    # self.new-sevens;
    # self.new-eights;
    # self.new-aces;
    # self.new-jacks;
    # self.new-aces-jacks;
    self.new-regular;
    for 0..6 { @!cards = @!cards.pick: *; }
  }

  method new-aces-jacks {
    self.new-irregular([0, 10]);
  }

  method new-jacks {
    self.new-irregular([10]);
  }

  method new-aces {
    self.new-irregular([0]);
  }

  method new-eights {
    self.new-irregular([7]);
  }

  method new-sevens {
    self.new-irregular([6]);
  }

  method new-regular {
    self.new-irregular([0..12]);
  }

  method new-irregular(@values) {
    @!cards = [];
    for 1 .. $!num-decks * 4 * 13 { for 0..3 -> $suite { for @values -> $v {
      my Card $a = Card.new(:value($v), :suite(Card.suites[$suite]), :suite-value($suite));
      @!cards.push($a);
    } } }
  }
}

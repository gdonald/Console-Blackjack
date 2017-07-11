
use Card;

class Shoe {
    has Pair @!shuffle-specs;
    has Int $!num-decks;
    has Card @!cards;

    submethod BUILD(:$!num-decks) {
        @!shuffle-specs = (80 => 1), (81 => 2), (82 => 3), (84 => 4), (86 => 5), (89 => 6), (92 => 7), (95 => 8);
	self.shuffle;
    }

    method get-next-card {
	return @!cards.pop;
    }
    
    method need-to-shuffle {
	return True if @!cards.elems == 0;

	my Int $total-cards = $!num-decks * 52;
	my Int $cards-dealt = $total-cards - @!cards.elems;
	my Rat $used-cards = ($cards-dealt / $total-cards) * 100.0;

	for 0..7 -> $x {
            my Int $allowed = @!shuffle-specs[$x].key;
	    my Int $decks   = @!shuffle-specs[$x].value;

	    if $!num-decks == $decks && $used-cards > $allowed {
		return True;
	    }
	}

	return False;
    }

    method shuffle {
	self.new-regular;
        # self.new-sevens;
        # self.new-eights;
        # self.new-aces;
        # self.new-jacks;
        # self.new-aces-jacks;
	for 0..6 { @!cards = @!cards.pick: *; }
    }

    method new-aces-jacks {
        @!cards = [];
        for 1 .. $!num-decks * 4 * 13 { for 0..3 -> $suite {
            my Card $a = Card.new(:value(0), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($a);
            my Card $j = Card.new(:value(10), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($j);
	} }
    }

    method new-jacks {
        @!cards = [];
        for 1 .. $!num-decks * 4 * 13 { for 0..3 -> $suite {
	    my Card $c = Card.new(:value(10), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($c);
	} }
    }

    method new-aces {
        @!cards = [];
        for 1 .. $!num-decks * 4 * 13 { for 0..3 -> $suite {
            my Card $c = Card.new(:value(0), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($c);
	} }
    }

    method new-eights {
        @!cards = [];
        for 1 .. $!num-decks * 4 * 13 { for 0..3 -> $suite {
            my Card $c = Card.new(:value(7), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($c);
	} }
    }

    method new-sevens {
        @!cards = [];
        for 1 .. $!num-decks * 4 * 13 { for 0..3 -> $suite {
            my Card $c = Card.new(:value(6), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($c);
	} }
    }

    method new-regular {
	@!cards = [];
	for 1 .. $!num-decks { for 0..3 -> $suite { for 0..12 -> $value {
            my Card $c = Card.new(:value($value), :suite(Card.suites[$suite]), :suite-value($suite));
	    @!cards.push($c);
	} } }
    }
}

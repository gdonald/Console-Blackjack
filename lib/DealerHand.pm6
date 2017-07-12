
use Hand;
use Card;

class DealerHand is Hand {

    has $!game;
    has Bool $.hide-down-card is rw;

    submethod BUILD(:$!game) {
        $!hide-down-card = True;
    }

    method get-value(Hand::CountMethod $count-method) {
        my Int $v = 0;
        my Int $total = 0;

        for @.cards.kv -> $k, $card {
            next if $k == 1 && $!hide-down-card;
            my Int $tmp_v = $card.value + 1;
            $v = $tmp_v > 9 ?? 10 !! $tmp_v;
            $v = 11 if $count-method == Hand::CountMethod::Soft && $v == 1 && $total < 11;
            $total += $v;
        }

        if $count-method == Hand::CountMethod::Soft && $total > 21 {
            return self.get-value(Hand::CountMethod::Hard);
        }

        return $total;
    }

    method up-card-is-ace {
        return @.cards[0].is-ace;
    }

    method draw {
        print ' ';
        for @.cards.kv -> $k, $card {
            print $k == 1 && $!hide-down-card ?? Card.faces[13][0] !! $card.draw;
            print ' ';
        }
        print ' ⇒  ';
        print self.get-value(Hand::CountMethod::Soft);
    }
}

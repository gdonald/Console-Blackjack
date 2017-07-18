
use Shoe;
use Card;

class Hand {

    enum CountMethod <Soft Hard>;
    enum Status <Unknown Won Lost Push>;

    has $!game; # untyped else circular dependency
    has Shoe $!shoe;
    has Card @.cards  is rw;
    has Bool $.stood  is rw;
    has Bool $.played is rw;

    submethod BUILD(:$!game) {
        $!shoe = $!game.shoe;
    }

    method is-busted(--> Bool) {
	self.get-value(Soft) > 21;
    }

    method is-blackjack(--> Bool) {
	return False if @.cards.elems != 2;
	return True  if @.cards[0].is-ace && @.cards[1].is-ten;
	return True  if @.cards[1].is-ace && @.cards[0].is-ten;
	False;
    }

    method is-done(--> Bool) {
	False;
    }

    method get-value(CountMethod $count-method, --> Int) {
	0;
    }

    method deal-card {
	@.cards.push: $!shoe.get-next-card;
    }
}

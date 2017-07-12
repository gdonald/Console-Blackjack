
class Card {
    my Str @.suites = <Spades Hearts Clubs Diamonds>;
    my Array @.faces = [
        ['🂡', '🂱', '🃁', '🃑'],
	['🂢', '🂲', '🃂', '🃒'],
	['🂣', '🂳', '🃃', '🃓'],
	['🂤', '🂴', '🃄', '🃔'],
	['🂥', '🂵', '🃅', '🃕'],
	['🂦', '🂶', '🃆', '🃖'],
	['🂧', '🂷', '🃇', '🃗'],
	['🂨', '🂸', '🃈', '🃘'],
	['🂩', '🂹', '🃉', '🃙'],
	['🂪', '🂺', '🃊', '🃚'],
	['🂫', '🂻', '🃋', '🃛'],
	['🂭', '🂽', '🃍', '🃝'],
	['🂮', '🂾', '🃎', '🃞'],
	['🂠', '', '', '']];

    has Int $.value;
    has Int $!suite-value;
    has Str $!suite;

    submethod BUILD(:$!value, :$!suite, :$!suite-value) {
    }

    method is-ace {
        return $!value == 0;
    }

    method is-ten {
	return $!value > 9;
    }

    method draw {
	return Card.faces[$!value][$!suite-value];
    }
}


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

    method is-ace(--> Bool) {
        $!value == 0;
    }

    method is-ten(--> Bool) {
	$!value > 9;
    }

    method draw(--> Str) {
	Card.faces[$!value][$!suite-value];
    }
}

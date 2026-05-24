use lib 'lib';
use BDD::Behave;
use Console::Blackjack;
use Console::Blackjack::Shoe;
use Console::Blackjack::DealerHand;
use Console::Blackjack::PlayerHand;
use Console::Blackjack::Hand;
use Console::Blackjack::Card;
use Console::Blackjack::Terminal;

class ScriptedTerminal is Terminal {
  has @.input;
  has Int $.cursor is rw = 0;
  has Int $.clear-calls is rw = 0;
  method read-one-char(--> Str) {
    die "ScriptedTerminal input exhausted at cursor=$!cursor (queue: @!input.join(','))"
      if $!cursor >= @!input.elems;
    @!input[$!cursor++];
  }
  method clear() { ++$!clear-calls; }
  method prompt($msg) {
    die "ScriptedTerminal prompt exhausted at cursor=$!cursor (queue: @!input.join(','))"
      if $!cursor >= @!input.elems;
    val(@!input[$!cursor++]);
  }
}

sub captured-out(&block --> Str) {
  my $out = '';
  my $*OUT = class {
    method print(*@a) { $out ~= @a.join; }
    method say(*@a)   { $out ~= @a.join ~ "\n"; }
    method flush      {}
  }.new;
  block();
  $out;
}

sub dealer-of($g) {
  $g.^attributes.first(*.name eq '$!dealer-hand').get_value($g);
}

sub quitting-of($g) {
  $g.^attributes.first(*.name eq '$!quitting').get_value($g);
}

sub current-bet-of($g) {
  $g.^attributes.first(*.name eq '$!current-bet').get_value($g);
}

sub fresh-dealer($g) {
  my $dh = DealerHand.new(game => $g);
  $g.^attributes.first(*.name eq '$!dealer-hand').set_value($g, $dh);
  $dh;
}

sub mk-game(*@input) {
  PlayerHand.total-player-hands = 0;
  'bj.txt'.IO.unlink if 'bj.txt'.IO.e;
  my $g = Game.new;
  $g.terminal = ScriptedTerminal.new(input => @input);
  $g;
}

sub install-shoe($g, Int :$deck-type, Int :$num-decks = 1) {
  Shoe.deck-type = $deck-type;
  Shoe.num-decks = $num-decks;
  $g.shoe = Shoe.new;
}

describe 'Game interactive flow', {
  let(:tmpdir, { ($*TMPDIR ~ '/console-blackjack-int-spec-' ~ $*PID).IO });
  let(:orig-cwd, { $*CWD });

  before-each {
    $*LET-RUNTIME.value('orig-cwd');
    my $tmp = $*LET-RUNTIME.value('tmpdir');
    $tmp.mkdir unless $tmp.e;
    chdir $tmp;
    Shoe.num-decks = 8;
    Shoe.deck-type = 1;
    Card.face-type = 1;
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

  describe 'Game.read-one-char delegates to terminal', {
    it 'returns the first char', {
      my $g = mk-game(<x y z>);
      expect($g.read-one-char).to.be('x');
    }

    it 'returns the second char', {
      my $g = mk-game(<x y z>);
      $g.read-one-char;
      expect($g.read-one-char).to.be('y');
    }

    it 'returns the third char', {
      my $g = mk-game(<x y z>);
      $g.read-one-char;
      $g.read-one-char;
      expect($g.read-one-char).to.be('z');
    }
  }

  describe 'Game.clear delegates to terminal.clear', {
    it 'increments terminal.clear-calls', {
      my $g = mk-game();
      $g.clear;
      $g.clear;
      expect($g.terminal.clear-calls).to.be(2);
    }
  }

  describe 'Terminal default class', {
    it 'Terminal.new returns a Terminal', {
      expect(Terminal.new).to.be-a(Terminal);
    }

    it 'has a read-one-char method', {
      expect(Terminal.new.can('read-one-char')).to.be-truthy;
    }

    it 'has a clear method', {
      expect(Terminal.new.can('clear')).to.be-truthy;
    }

    it 'has a prompt method', {
      expect(Terminal.new.can('prompt')).to.be-truthy;
    }

    it 'clear writes the home + clear escape bytes to $*OUT', {
      my $captured = '';
      {
        my $*OUT = class {
          method print(*@a) { $captured ~= @a.join; }
          method say(*@a)   { $captured ~= @a.join ~ "\n"; }
          method flush      {}
        }.new;
        Terminal.new.clear;
      }
      expect($captured).to.be("\e[H\e[J");
    }

    it 'prompt returns a line read from $*IN', {
      my $tmp = ($*TMPDIR ~ '/console-blackjack-terminal-prompt-spec-' ~ $*PID).IO;
      $tmp.spurt("hello\n");
      my $fh = $tmp.open;
      my $r;
      my $sink = '';
      {
        my $*IN  = $fh;
        my $*OUT = class {
          method print(*@a) { $sink ~= @a.join; }
          method say(*@a)   { $sink ~= @a.join ~ "\n"; }
          method flush      {}
        }.new;
        $r = Terminal.new.prompt('msg: ');
      }
      $fh.close;
      $tmp.unlink;
      expect($r).to.be('hello');
    }
  }

  describe 'draw-hands output', {
    let(:rendered, {
      my $g = mk-game();
      fresh-dealer($g).cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      my $out = captured-out(-> { $g.draw-hands; });
      %( :game($g), :out($out) );
    });

    it 'renders the Dealer label', {
      expect($*LET-RUNTIME.value('rendered')<out>).to.include('Dealer');
    }

    it 'renders the Player label', {
      expect($*LET-RUNTIME.value('rendered')<out>).to.include('Player');
    }

    it 'renders dealer cards', {
      expect($*LET-RUNTIME.value('rendered')<out>).to.include('A♠');
    }

    it 'calls terminal.clear', {
      expect($*LET-RUNTIME.value('rendered')<game>.terminal.clear-calls).to.be(1);
    }
  }

  describe 'insure-hand', {
    let(:setup, {
      my $g = mk-game('q');
      my $ph = PlayerHand.new(game => $g, bet => 10.0);
      $ph.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      my $start = $g.money;
      captured-out(-> { $g.insure-hand; });
      %( :game($g), :hand($ph), :start($start) );
    });

    it 'halves the bet', {
      expect($*LET-RUNTIME.value('setup')<hand>.bet).to.be(5.0);
    }

    it 'marks played', {
      expect($*LET-RUNTIME.value('setup')<hand>.played).to.be-truthy;
    }

    it 'marks paid', {
      expect($*LET-RUNTIME.value('setup')<hand>.paid).to.be-truthy;
    }

    it 'sets status to Lost', {
      expect($*LET-RUNTIME.value('setup')<hand>.status).to.be(Hand::Status::Lost);
    }

    it 'deducts halved bet from money', {
      my %s = $*LET-RUNTIME.value('setup');
      expect(%s<game>.money).to.be(%s<start> - 5.0);
    }

    it 'chains into draw-player-bet-options which sees q', {
      expect(quitting-of($*LET-RUNTIME.value('setup')<game>)).to.be-truthy;
    }
  }

  describe 'ask-insurance', {
    it 'y goes through insure-hand', {
      my $g = mk-game('y', 'q');
      my $ph = PlayerHand.new(game => $g, bet => 10.0);
      $ph.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.ask-insurance; });
      expect($ph.status).to.be(Hand::Status::Lost);
    }

    describe 'n + dealer blackjack', {
      let(:result, {
        my $g = mk-game('n', 'q');
        fresh-dealer($g).cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
        my $ph = PlayerHand.new(game => $g, bet => 10.0);
        $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
        $g.player-hands.push($ph);
        my $start = $g.money;
        captured-out(-> { $g.ask-insurance; });
        %( :game($g), :hand($ph), :start($start) );
      });

      it 'marks player Lost', {
        expect($*LET-RUNTIME.value('result')<hand>.status).to.be(Hand::Status::Lost);
      }

      it 'deducts bet', {
        my %r = $*LET-RUNTIME.value('result');
        expect(%r<game>.money).to.be(%r<start> - 10.0);
      }

      it 'ends at bet-options q', {
        expect(quitting-of($*LET-RUNTIME.value('result')<game>)).to.be-truthy;
      }
    }

    describe 'n + player blackjack', {
      let(:result, {
        my $g = mk-game('n', 'q');
        fresh-dealer($g).cards = [Card.new(value => 0, suit => 0), Card.new(value => 4, suit => 0)];
        my $ph = PlayerHand.new(game => $g, bet => 10.0);
        $ph.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
        $g.player-hands.push($ph);
        my $start = $g.money;
        captured-out(-> { $g.ask-insurance; });
        %( :game($g), :hand($ph), :start($start) );
      });

      it 'marks player Won', {
        expect($*LET-RUNTIME.value('result')<hand>.status).to.be(Hand::Status::Won);
      }

      it 'credits the bet', {
        my %r = $*LET-RUNTIME.value('result');
        expect(%r<game>.money > %r<start>).to.be-truthy;
      }
    }

    it 'n + neither dealer-BJ nor player-done → get-action', {
      my $g = mk-game('n', 's', 'q');
      fresh-dealer($g).cards = [Card.new(value => 0, suit => 0), Card.new(value => 4, suit => 0)];
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.ask-insurance; });
      expect($ph.stood).to.be-truthy;
    }

    it 'recovers from invalid char via recursion', {
      my $g = mk-game('x', 'y', 'q');
      my $ph = PlayerHand.new(game => $g, bet => 10.0);
      $ph.cards = [Card.new(value => 0, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.ask-insurance; });
      expect($ph.status).to.be(Hand::Status::Lost);
    }
  }

  describe 'draw-player-bet-options', {
    it 'q sets quitting', {
      my $g = mk-game('q');
      captured-out(-> { $g.draw-player-bet-options; });
      expect(quitting-of($g)).to.be-truthy;
    }

    it 'b → get-new-bet sets current-bet', {
      my $g = mk-game('b', '25', 's', 'q');
      install-shoe($g, deck-type => 3);
      captured-out(-> { $g.draw-player-bet-options; });
      expect(current-bet-of($g)).to.be(25.0);
    }

    it 'o → game-options b → bet-options q', {
      my $g = mk-game('o', 'b', 'q');
      captured-out(-> { $g.draw-player-bet-options; });
      expect(quitting-of($g)).to.be-truthy;
    }

    it 'd does not quit', {
      my $g = mk-game('d');
      captured-out(-> { $g.draw-player-bet-options; });
      expect(quitting-of($g)).to.be-falsy;
    }

    it 'invalid char recurses, next char takes effect', {
      my $g = mk-game('x', 'q');
      captured-out(-> { $g.draw-player-bet-options; });
      expect(quitting-of($g)).to.be-truthy;
    }
  }

  describe 'game-options', {
    it 'n → get-new-num-decks sets num-decks', {
      my $g = mk-game('n', '4', 'b', 'q');
      captured-out(-> { $g.game-options; });
      expect(Shoe.num-decks).to.be(4);
    }

    it 't → get-new-deck-type sets deck-type', {
      my $g = mk-game('t', '2', 'q');
      captured-out(-> { $g.game-options; });
      expect(Shoe.deck-type).to.be(2);
    }

    it 'f → get-new-face-type sets face-type', {
      Card.face-type = 1;
      my $g = mk-game('f', '2', 'q');
      captured-out(-> { $g.game-options; });
      expect(Card.face-type).to.be(2);
    }

    it 'b returns to bet-options', {
      my $g = mk-game('b', 'q');
      captured-out(-> { $g.game-options; });
      expect(quitting-of($g)).to.be-truthy;
    }

    it 'invalid char recurses', {
      my $g = mk-game('x', 'b', 'q');
      captured-out(-> { $g.game-options; });
      expect(quitting-of($g)).to.be-truthy;
    }
  }

  describe 'get-new-face-type', {
    after-each { Card.face-type = 1; }

    it '2 sets face-type=2', {
      Card.face-type = 1;
      my $g = mk-game('2', 'q');
      captured-out(-> { $g.get-new-face-type; });
      expect(Card.face-type).to.be(2);
    }

    it '1 sets face-type=1', {
      Card.face-type = 2;
      my $g = mk-game('1', 'q');
      captured-out(-> { $g.get-new-face-type; });
      expect(Card.face-type).to.be(1);
    }

    it 'default char recurses, eventually quits', {
      Card.face-type = 1;
      my $g = mk-game('x', '2', 'q', 'q');
      captured-out(-> { $g.get-new-face-type; });
      expect(quitting-of($g)).to.be-truthy;
    }
  }

  describe 'get-new-deck-type', {
    after-each {
      Shoe.deck-type = 1;
      Shoe.num-decks = 8;
    }

    for 1..6 -> $type {
      it "$type sets deck-type=$type", {
        Shoe.deck-type = 1;
        Shoe.num-decks = 1;
        my $g = mk-game($type.Str, 'q');
        captured-out(-> { $g.get-new-deck-type; });
        expect(Shoe.deck-type).to.be($type);
      }

      if $type != 1 {
        it "$type forces num-decks=8", {
          Shoe.deck-type = 1;
          Shoe.num-decks = 1;
          my $g = mk-game($type.Str, 'q');
          captured-out(-> { $g.get-new-deck-type; });
          expect(Shoe.num-decks).to.be(8);
        }
      }
    }

    it 'default char recurses, eventually quits', {
      Shoe.deck-type = 1;
      my $g = mk-game('x', '3', 'q', 'q');
      captured-out(-> { try { $g.get-new-deck-type; } });
      expect(quitting-of($g)).to.be-truthy;
    }
  }

  describe 'get-new-num-decks', {
    after-each { Shoe.num-decks = 8; }

    it 'sets num-decks from prompt', {
      Shoe.num-decks = 1;
      my $g = mk-game('5', 'b', 'q');
      captured-out(-> { $g.get-new-num-decks; });
      expect(Shoe.num-decks).to.be(5);
    }

    it 'clamps 0 up to 1', {
      Shoe.num-decks = 4;
      my $g = mk-game('0', 'b', 'q');
      captured-out(-> { $g.get-new-num-decks; });
      expect(Shoe.num-decks).to.be(1);
    }

    it 'clamps 99 down to 8', {
      Shoe.num-decks = 4;
      my $g = mk-game('99', 'b', 'q');
      captured-out(-> { $g.get-new-num-decks; });
      expect(Shoe.num-decks).to.be(8);
    }
  }

  describe 'get-new-bet', {
    it 'sets current-bet', {
      my $g = mk-game('b', '50', 's', 'q');
      install-shoe($g, deck-type => 3);
      captured-out(-> { $g.draw-player-bet-options; });
      expect(current-bet-of($g)).to.be(50.0);
    }
  }

  describe 'play-more-hands', {
    it 'advances current-player-hand', {
      my $g = mk-game('s', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $h1 = PlayerHand.new(game => $g, bet => 5.0);
      $h1.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $h1.played = True;
      my $h2 = PlayerHand.new(game => $g, bet => 5.0);
      $h2.cards = [Card.new(value => 5, suit => 0)];
      $g.player-hands.push($h1);
      $g.player-hands.push($h2);
      captured-out(-> { $g.play-more-hands; });
      expect($g.current-player-hand).to.be(1);
    }

    it 'deals a card to the next hand', {
      my $g = mk-game('s', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $h1 = PlayerHand.new(game => $g, bet => 5.0);
      $h1.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $h1.played = True;
      my $h2 = PlayerHand.new(game => $g, bet => 5.0);
      $h2.cards = [Card.new(value => 5, suit => 0)];
      $g.player-hands.push($h1);
      $g.player-hands.push($h2);
      captured-out(-> { $g.play-more-hands; });
      expect($h2.cards.elems >= 2).to.be-truthy;
    }

    it 'processes the hand when it becomes done', {
      my $g = mk-game('q');
      install-shoe($g, deck-type => 6);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $h1 = PlayerHand.new(game => $g, bet => 5.0);
      $h1.cards = [Card.new(value => 0, suit => 0), Card.new(value => 12, suit => 0)];
      $h1.played = True;
      my $h2 = PlayerHand.new(game => $g, bet => 5.0);
      $h2.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($h1);
      $g.player-hands.push($h2);
      captured-out(-> { $g.play-more-hands; });
      expect($h2.played).to.be-truthy;
    }
  }

  describe 'split-current-hand', {
    it 'on non-pair does not add a hand', {
      my $g = mk-game('s', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.split-current-hand; });
      expect($g.player-hands.elems).to.be(1);
    }

    it 'on a pair creates a second hand', {
      my $g = mk-game('s', 's', 'q');
      install-shoe($g, deck-type => 5);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.split-current-hand; });
      expect($g.player-hands.elems).to.be(2);
    }

    it 'auto-done branch creates two hands', {
      my $g = mk-game('q');
      install-shoe($g, deck-type => 2);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.split-current-hand; });
      expect($g.player-hands.elems).to.be(2);
    }

    it 'auto-done first hand is processed', {
      my $g = mk-game('q');
      install-shoe($g, deck-type => 2);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $g.split-current-hand; });
      expect($g.player-hands[0].played).to.be-truthy;
    }
  }

  describe 'play-dealer-hand with eights-only shoe', {
    let(:setup, {
      my $g = mk-game();
      install-shoe($g, deck-type => 6);
      fresh-dealer($g).cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 8, suit => 0), Card.new(value => 8, suit => 1)];
      $g.player-hands.push($ph);
      my $start = $g.money;
      captured-out(-> { $g.play-dealer-hand; });
      %( :game($g), :hand($ph), :start($start) );
    });

    it 'busts the dealer', {
      expect(dealer-of($*LET-RUNTIME.value('setup')<game>).is-busted).to.be-truthy;
    }

    it 'player wins when dealer busts', {
      expect($*LET-RUNTIME.value('setup')<hand>.status).to.be(Hand::Status::Won);
    }

    it 'credits bet when dealer busts', {
      my %s = $*LET-RUNTIME.value('setup');
      expect(%s<game>.money).to.be(%s<start> + 5.0);
    }
  }

  describe 'splitting aces fills player-hands to max', {
    it 'reaches PlayerHand.max-player-hands', {
      my $g = mk-game('p', 'p', 'p', 'p', 'p', 'p', 's', 's', 's', 's', 's', 's', 's', 'q');
      install-shoe($g, deck-type => 2);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 0, suit => 0), Card.new(value => 0, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.get-action; });
      expect($g.player-hands.elems).to.be(PlayerHand.max-player-hands);
    }
  }

  describe 'deal-new-hand', {
    it 'dealer ace up triggers ask-insurance flow', {
      my $g = mk-game('n', 's', 's', 'q', 'q');
      install-shoe($g, deck-type => 2);
      captured-out(-> { $g.deal-new-hand; });
      expect($g.player-hands.elems).to.be(1);
    }

    it 'deals at least two cards to the dealer', {
      my $g = mk-game('n', 's', 's', 'q', 'q');
      install-shoe($g, deck-type => 2);
      captured-out(-> { $g.deal-new-hand; });
      expect(dealer-of($g).cards.elems >= 2).to.be-truthy;
    }

    it 'aces+jacks shoe creates a player hand', {
      my $g = mk-game('n', 's', 's', 'q', 'q');
      install-shoe($g, deck-type => 4);
      captured-out(-> { $g.deal-new-hand; });
      expect($g.player-hands.elems).to.be(1);
    }

    it 'normal flow creates a player hand', {
      my $g = mk-game('s', 'q');
      install-shoe($g, deck-type => 3);
      captured-out(-> { $g.deal-new-hand; });
      expect($g.player-hands.elems).to.be(1);
    }

    it 'reshuffles when the shoe is empty', {
      my $g = mk-game('s', 'q');
      install-shoe($g, deck-type => 3);
      $g.shoe.get-next-card for 1..$g.shoe.get-total-cards;
      captured-out(-> { $g.deal-new-hand; });
      expect($g.player-hands.elems).to.be(1);
    }

    describe 'player gets blackjack on initial deal (rigged shoe)', {
      let(:setup, {
        my $g = mk-game('q');
        my $shoe = $g.shoe;
        my $cards = $shoe.^attributes.first(*.name eq '@!cards').get_value($shoe);
        $cards.push(
          Card.new(value => 4, suit => 0),
          Card.new(value => 12, suit => 0),
          Card.new(value => 4, suit => 1),
          Card.new(value => 0, suit => 0),
        );
        captured-out(-> { $g.deal-new-hand; });
        $g;
      });

      it 'leaves the player hand as a blackjack', {
        expect($*LET-RUNTIME.value('setup').player-hands[0].is-blackjack).to.be-truthy;
      }

      it 'pays out via pay-hands (player-done branch)', {
        expect($*LET-RUNTIME.value('setup').player-hands[0].status).to.be(Hand::Status::Won);
      }
    }
  }

  describe 'run', {
    it 'sets quitting=True via bet-options q', {
      my $g = mk-game('s', 'q');
      install-shoe($g, deck-type => 3);
      captured-out(-> { $g.run; });
      expect(quitting-of($g)).to.be-truthy;
    }
  }

  describe 'PlayerHand.hit', {
    describe 'not-done branch (deterministic via sevens shoe)', {
      let(:setup, {
        my $g = mk-game('s', 'q');
        install-shoe($g, deck-type => 5);
        fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
        dealer-of($g).hide-down-card = False;
        my $ph = PlayerHand.new(game => $g, bet => 5.0);
        $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 4, suit => 1)];
        $g.player-hands.push($ph);
        captured-out(-> { $ph.hit; });
        $ph;
      });

      it 'adds exactly one card', {
        expect($*LET-RUNTIME.value('setup').cards.elems).to.be(3);
      }

      it 'does not bust', {
        expect($*LET-RUNTIME.value('setup').is-busted).to.be-falsy;
      }

      it 'chains into get-action and stands', {
        expect($*LET-RUNTIME.value('setup').stood).to.be-truthy;
      }
    }

    it 'can lead to bust with eights-only shoe', {
      my $g = mk-game('q');
      install-shoe($g, deck-type => 6);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.hit; });
      expect($ph.is-busted).to.be-truthy;
    }

    it 'busting hit marks played', {
      my $g = mk-game('q');
      install-shoe($g, deck-type => 6);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.hit; });
      expect($ph.played).to.be-truthy;
    }
  }

  describe 'PlayerHand.stand', {
    it 'sets stood', {
      my $g = mk-game('q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.stand; });
      expect($ph.stood).to.be-truthy;
    }

    it 'sets played', {
      my $g = mk-game('q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.stand; });
      expect($ph.played).to.be-truthy;
    }

    it 'advances to next hand when more remain', {
      my $g = mk-game('s', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $h1 = PlayerHand.new(game => $g, bet => 5.0);
      $h1.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      my $h2 = PlayerHand.new(game => $g, bet => 5.0);
      $h2.cards = [Card.new(value => 5, suit => 0)];
      $g.player-hands.push($h1);
      $g.player-hands.push($h2);
      captured-out(-> { $h1.stand; });
      expect($g.current-player-hand).to.be(1);
    }
  }

  describe 'PlayerHand.dbl', {
    let(:setup, {
      my $g = mk-game('q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.dbl; });
      %( :game($g), :hand($ph) );
    });

    it 'doubles the bet', {
      expect($*LET-RUNTIME.value('setup')<hand>.bet).to.be(10.0);
    }

    it 'marks played', {
      expect($*LET-RUNTIME.value('setup')<hand>.played).to.be-truthy;
    }

    it 'deals exactly one card', {
      expect($*LET-RUNTIME.value('setup')<hand>.cards.elems).to.be(3);
    }
  }

  describe 'PlayerHand.process', {
    it 'with more hands → play-more-hands', {
      my $g = mk-game('s', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $h1 = PlayerHand.new(game => $g, bet => 5.0);
      $h1.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      my $h2 = PlayerHand.new(game => $g, bet => 5.0);
      $h2.cards = [Card.new(value => 5, suit => 0)];
      $g.player-hands.push($h1);
      $g.player-hands.push($h2);
      captured-out(-> { $h1.process; });
      expect($g.current-player-hand).to.be(1);
    }

    it 'drives play-dealer-hand + bet-options', {
      my $g = mk-game('q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $ph.played = True;
      $g.player-hands.push($ph);
      captured-out(-> { $ph.process; });
      expect(quitting-of($g)).to.be-truthy;
    }
  }

  describe 'PlayerHand.get-action', {
    it 'h triggers hit', {
      my $g = mk-game('h', 's', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.get-action; });
      expect($ph.cards.elems >= 3).to.be-truthy;
    }

    it 's triggers stand', {
      my $g = mk-game('s', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.get-action; });
      expect($ph.stood).to.be-truthy;
    }

    it 'p triggers split', {
      my $g = mk-game('p', 's', 's', 'q');
      install-shoe($g, deck-type => 5);
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 7, suit => 0), Card.new(value => 7, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.get-action; });
      expect($g.player-hands.elems).to.be(2);
    }

    it 'd triggers dbl', {
      my $g = mk-game('d', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.get-action; });
      expect($ph.bet).to.be(10.0);
    }

    it 'default char recurses, next char takes effect', {
      my $g = mk-game('x', 's', 'q');
      fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
      dealer-of($g).hide-down-card = False;
      my $ph = PlayerHand.new(game => $g, bet => 5.0);
      $ph.cards = [Card.new(value => 9, suit => 0), Card.new(value => 9, suit => 1)];
      $g.player-hands.push($ph);
      captured-out(-> { $ph.get-action; });
      expect($ph.stood).to.be-truthy;
    }

    describe "'h' on hard-21 (can-hit False)", {
      let(:setup, {
        my $g = mk-game('h', 's', 'q');
        fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
        dealer-of($g).hide-down-card = False;
        my $ph = PlayerHand.new(game => $g, bet => 5.0);
        $ph.cards = [
          Card.new(value => 6, suit => 0),
          Card.new(value => 6, suit => 1),
          Card.new(value => 6, suit => 2),
        ];
        $g.player-hands.push($ph);
        captured-out(-> { $ph.get-action; });
        $ph;
      });

      it 'does not add a card', {
        expect($*LET-RUNTIME.value('setup').cards.elems).to.be(3);
      }

      it 'is a no-op, then s stands', {
        expect($*LET-RUNTIME.value('setup').stood).to.be-truthy;
      }
    }

    describe "'p' on a non-pair (can-split False)", {
      let(:setup, {
        my $g = mk-game('p', 's', 'q');
        fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
        dealer-of($g).hide-down-card = False;
        my $ph = PlayerHand.new(game => $g, bet => 5.0);
        $ph.cards = [Card.new(value => 4, suit => 0), Card.new(value => 5, suit => 0)];
        $g.player-hands.push($ph);
        captured-out(-> { $ph.get-action; });
        %( :game($g), :hand($ph) );
      });

      it 'does not split', {
        expect($*LET-RUNTIME.value('setup')<game>.player-hands.elems).to.be(1);
      }

      it 'is a no-op, then s stands', {
        expect($*LET-RUNTIME.value('setup')<hand>.stood).to.be-truthy;
      }
    }

    describe "'d' on a 3-card hand (can-dbl False)", {
      let(:setup, {
        my $g = mk-game('d', 's', 'q');
        fresh-dealer($g).cards = [Card.new(value => 9, suit => 0), Card.new(value => 8, suit => 0)];
        dealer-of($g).hide-down-card = False;
        my $ph = PlayerHand.new(game => $g, bet => 5.0);
        $ph.cards = [
          Card.new(value => 1, suit => 0),
          Card.new(value => 2, suit => 0),
          Card.new(value => 3, suit => 0),
        ];
        $g.player-hands.push($ph);
        captured-out(-> { $ph.get-action; });
        $ph;
      });

      it 'does not double the bet', {
        expect($*LET-RUNTIME.value('setup').bet).to.be(5.0);
      }

      it 'is a no-op, then s stands', {
        expect($*LET-RUNTIME.value('setup').stood).to.be-truthy;
      }
    }
  }
}

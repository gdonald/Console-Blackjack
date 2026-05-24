
unit class Console::Blackjack::Terminal;

class Terminal is export {
  method read-one-char(--> Str) {
    my $tty = "/dev/tty".IO.open;
    shell "stty raw -echo min 1 time 1";
    my Str $c = $tty.read(1).decode('utf-8');
    shell "stty sane";
    $c;
  }

  method clear() {
    print "\e[H\e[J";
  }

  method prompt($msg) {
    prompt $msg;
  }
}

use BDD::Behave;
use JSON::Fast;

describe 'META6.json', {
  let(:meta, { from-json('META6.json'.IO.slurp) });

  it 'declares the project name', {
    expect($*LET-RUNTIME.value('meta')<name>).to.be('Console::Blackjack');
  }

  it 'declares a version', {
    expect($*LET-RUNTIME.value('meta')<version>).to.match(/^ \d+ \. \d+ \. \d+ $/);
  }

  it 'declares perl 6.d', {
    expect($*LET-RUNTIME.value('meta')<perl>).to.be('6.d');
  }

  it 'declares the author', {
    expect($*LET-RUNTIME.value('meta')<authors>).to.include('Greg Donald');
  }

  it 'declares the Artistic-2.0 license', {
    expect($*LET-RUNTIME.value('meta')<license>).to.be('Artistic-2.0');
  }

  it 'lists at least one provided module', {
    expect($*LET-RUNTIME.value('meta')<provides>.elems).to.be-greater-than(0);
  }
}

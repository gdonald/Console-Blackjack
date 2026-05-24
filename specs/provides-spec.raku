use BDD::Behave;
use JSON::Fast;

sub find-rakumod(IO::Path $dir) {
  gather for $dir.dir {
    when .d                      { .take for find-rakumod($_) }
    when .extension eq 'rakumod' { .take }
  }
}

describe 'META6.json provides', {
  let(:provided, {
    from-json('META6.json'.IO.slurp)<provides>.values.Set;
  });

  it 'lists every rakumod file under lib/', {
    my $provided = $*LET-RUNTIME.value('provided');
    my @missing  = find-rakumod('lib'.IO).grep({ ! $provided{.relative} });
    expect(@missing.elems).to.be(0);
  }
}

#!/usr/bin/env raku

use v6.d;

$*OUT.out-buffer = False;

%*ENV<AUTHOR_TESTING> = 1;

chdir $*PROGRAM.parent;

my $jobs = max(2, ($*KERNEL.cpu-cores // 2) - 2);

my @stages = (
  { :name<prove6>, :cmd['prove6', "-j$jobs", '-Ilib', 't'], :env(%()) },
  { :name<behave>, :cmd['behave', '--parallel', $jobs.Str], :env(%()) },
);

my %durations;
my $total-start = now;

sub format-ts(--> Str) {
  my $d = DateTime.now;
  sprintf '%04d-%02d-%02d %02d:%02d:%02d',
  $d.year, $d.month, $d.day,
  $d.hour, $d.minute, $d.second.Int;
}

END {
  say '';
  say '==> Runtimes';
  for @stages -> $s {
    next unless %durations{$s<name>}:exists;
    printf "  %-7s %7.2fs\n", $s<name>, %durations{$s<name>};
  }
  printf "  %-7s %7.2fs\n", 'total', (now - $total-start).Num;
}

for @stages -> $s {
  my @cmd = $s<cmd>.list;
  my %extra-env = ($s<env> // %()).hash;
  my $env-prefix = %extra-env.elems
  ?? %extra-env.kv.map(-> $k, $v { "$k=$v" }).join(' ') ~ ' '
  !! '';
  say "==> [{format-ts()}] $env-prefix@cmd.join(' ')";
  my $start = now;
  my %old-env;
  for %extra-env.kv -> $k, $v {
    %old-env{$k} = %*ENV{$k};
    %*ENV{$k} = $v;
  }
  my $proc = run(|@cmd);
  for %old-env.kv -> $k, $v {
    if $v.defined { %*ENV{$k} = $v } else { %*ENV{$k}:delete }
  }
  %durations{$s<name>} = (now - $start).Num;
  exit $proc.exitcode unless $proc.exitcode == 0;
  say '';
}

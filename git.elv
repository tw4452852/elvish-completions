use ./comp
use re
use github.com/muesli/elvish-libs/git
use github.com/zzamboni/elvish-modules/util

completions = [&]

status = [&]

git-arg-completer = { }

git-command = git

modified-style  = yellow
untracked-style = red
tracked-style   = ''
branch-style    = blue
remote-style    = cyan

fn -run-git [@rest]{
  gitcmds = [$git-command]
  if (eq (kind-of $git-command) string) {
    gitcmds = [(splits " " $git-command)]
  }
  cmd = $gitcmds[0]
  if (eq (kind-of $cmd) string) {
    cmd = (external $cmd)
  }
  $cmd (explode $gitcmds[1:]) $@rest
}

fn -git-opts [@cmd]{
  _ = ?(-run-git $@cmd -h 2>&1) | drop 1 | if (eq $cmd []) {
    comp:extract-opts &fold=$true &regex='--(\w[\w-]*)' &regex-map=[&long=1]
  } else {
    comp:extract-opts &fold=$true
  }
}

fn MODIFIED      { explode $status[local-modified] | comp:decorate &style=$modified-style }
fn UNTRACKED     { explode $status[untracked] | comp:decorate &style=$untracked-style }
fn MOD-UNTRACKED { MODIFIED; UNTRACKED }
fn TRACKED       { _ = ?(-run-git ls-files 2>/dev/null) | comp:decorate &style=$tracked-style }
fn BRANCHES      [&all=$false]{
  -allarg = []
  if $all { -allarg = ['--all'] }
  _ = ?(-run-git branch --list (explode $-allarg) --format '%(refname:short)' 2>/dev/null |
  comp:decorate &display-suffix=' (branch)' &style=$branch-style)
}
fn REMOTES       { _ = ?(-run-git remote 2>/dev/null | comp:decorate &display-suffix=' (remote)' &style=$remote-style ) }

git-completions = [
  &add=      [ [stem]{ MOD-UNTRACKED; comp:dirs $stem } ... ]
  &stage=    add
  &checkout= [ { MODIFIED; BRANCHES } ... ]
  &mv=       [ [stem]{ TRACKED; comp:dirs $stem } ... ]
  &rm=       [ [stem]{ TRACKED; comp:dirs $stem } ... ]
  &diff=     [ { MODIFIED; BRANCHES  } ... ]
  &push=     [ $REMOTES~ $BRANCHES~ ]
  &pull=     [ $REMOTES~ { BRANCHES &all } ]
  &merge=    [ $BRANCHES~ ... ]
  &init=     [ [stem]{ put "."; comp:dirs $stem } ]
  &branch=   [ $BRANCHES~ ... ]
]

fn init {
    completions = [&]
    -run-git help -a --no-verbose | eawk [line @f]{ if (re:match '^  [a-z]' $line) { put $@f } } | each [c]{
      seq = [ $comp:files~ ... ]
      if (has-key $git-completions $c) {
        seq = $git-completions[$c]
      }
      if (eq (kind-of $seq 'string')) {
        completions[$c] = $seq
      } else {
        completions[$c] = (comp:sequence $seq &opts={ -git-opts $c })
      }
    }
    -run-git config --list | each [l]{ re:find '^alias\.([^=]+)=(.*)$' $l } | each [m]{
      alias target = $m[groups][1 2][text]
      if (has-key $completions $target) {
        completions[$alias] = $target
      } else {
        completions[$alias] = (comp:sequence [])
      }
    }
    git-arg-completer = (comp:subcommands $completions \
      &pre-hook=[@_]{ status = (git:status) } &opts={ -git-opts }
    )
    edit:completion:arg-completer[git] = $git-arg-completer
}

init

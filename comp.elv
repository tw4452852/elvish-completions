use re
use github.com/zzamboni/elvish-modules/util

fn decorate [&code-suffix='' &display-suffix='' &suffix='' &style='' @input]{
  if (eq (count $input) 0) {
    input = [(all)]
  }
  if (not-eq $suffix '') {
    display-suffix = $suffix
    code-suffix = $suffix
  }
  each [k]{
    edit:complex-candidate &code-suffix=$code-suffix &display-suffix=$display-suffix &style=$style $k
  } $input
}

fn item [def @cmd]{
  arg = $cmd[-1]
  what = (kind-of $def)
  if (eq $what 'fn') {
    fnargs = [ (count $def[arg-names]) (not-eq $def[rest-arg] '') ]
    if (eq $fnargs [ 0 $false ]) {
      $def
    } elif (eq $fnargs [ 1 $false ]) {
      $def $arg
    } elif (eq $fnargs [ 0 $true ]) {
      $def $@cmd
    }
  } elif (eq $what 'list') {
    explode $def
  }
}

fn sequence [def @cmd]{
  n = (count $cmd)
  cmd-wo = [(each [p]{ if (not (re:match "^-" $p)) { put $p } } $cmd)]
  n-wo = (count $cmd-wo)
  if (and (eq $n-wo 2) (has-key $def -opts)) {
    item $def[-opts] $@cmd
  }
  item $def[-seq][(util:min (- $n-wo 2) (- (count $def[-seq]) 1))] $@cmd
}

fn subcommands [def @cmd]{
  n = (count $cmd)

if (eq $n 2) {
  keys (dissoc $def -opts)
  if (has-key $def -opts) {
    item $def[-opts] $@cmd
  }

} else {
    subcommand = $cmd[1]
    if (has-key $def $subcommand) {
      if (eq (kind-of $def[$subcommand]) 'string') {
        subcommands $def $cmd[0] $def[$subcommand] (explode $cmd[2:])
      } else {
        sequence $def[$subcommand] (explode $cmd[1:])
      }
    }
  }
}

fn -wrapper-gen [func]{
  put [def]{ put [@cmd]{ $func $def $@cmd } }
}

item-wrapper~ = (-wrapper-gen $item~)
sequence-wrapper~ = (-wrapper-gen $sequence~)
subcommands-wrapper~ = (-wrapper-gen $subcommands~)

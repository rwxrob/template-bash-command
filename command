#!/usr/bin/bash
# shellcheck disable=SC2016
set -e
export PATH="/usr/bin:/usr/local/bin"

# Copyright 2021 Rob Muhlestein <rob@rwx.gg>
# Released under Apache-2.0 license
# Please mention https://youtube.com/rwxrob

(( BASH_VERSINFO[0] < 4 )) && echo "Bash 4+ required." && exit 1

: "${PAGER:=more}"
: "${EDITOR:=vi}"
: "${HELP_BROWSER:=}"

EXE="${0##*/}"

declare -A help # associative arrays *require* declaration

help[main]='
# Sample Bash Template Command

This `command` contains the scaffolding for Bash tab completion using
the `complete -C foo foo` variation which allows scripts to complete
themselves (rather than having another script somewhere to manage). To
use it simply add a function with the additional command and add the
name of it to the commands array declaration at the top of the script.
Then add `complete -C foo foo` to your bashrc.  Begin functions with
`command_` to allow useful command names to be used that would otherwise
conflict with existing system and bash keywords.  Begin functions with
`command__` when you do not want them to appear with tab completion, but
still want them to be available, just hidden.'

help[foo]='The `foo` command foos.'

command_foo() {
  _filter "$@" && return $?
  echo "would foo: $*"
}

help[bar]='The `bar` command bars.'

command_bar() {
  _buffer "$@" && return $?
  echo "would bar: $*"
}

command__hidden() {
  _filter "$@" && return $?
  echo "would run _hidden: $*"
}

help[usage]='The `usage` command displays a summary of usage.'

command_usage() {
  local -a cmds
  for c in "${COMMANDS[@]}"; do
    [[ ${c:0:1} =~ _ ]] && continue
    cmds+=($c)
  done
  cmds="${cmds[*]}"
  printf "usage: %s (%s)\n" "$EXE" "${cmds// /|}"
}

help[help]='
# The `help` Command

The `help` command prints help information. If no argument is passed
displays general help information (main). Otherwise, the documentation
for the specific argument keyword is displayed, which usually
corresponds to a command name (but not necessarily). All documentation
is written in CommonMark (Markdown) and will displayed as Web page if
`pandoc` and `$HELP_BROWSER` are detected, otherwise, just the Markdown is
sent to `$PAGER` (default: more).'

command_help() { 
  local name="$1"
  if [[ -z "$name" ]];then
    for c in "${COMMANDS[@]}";do
      [[ ${c:0:1} = _ ]] && continue;
      command_help "$c" buildonly || true
    done
    command_help main
    return 0
  fi
  local title own body
  title=$(_help_title "$name")
  if [[ -z "$title" ]]; then
    body="${help[$name]}"
    title="$EXE $name"
    [[ $name = main ]] && title="$EXE"
  else
    body="${help[$name]}"
    local eol=$'\n'
    body=${body#*$title}
  fi
  local file="/tmp/help-$EXE-$name.html"
  if _have pandoc ; then
    if _have "$HELP_BROWSER" && [[ -t 1 ]] ;then
      pandoc -s --metadata title="$title" \
        -o "$file" <<< "$body"
      [[ -z "$2" ]] && cd /tmp && exec "$HELP_BROWSER" "$file"
      return 0
    fi
    pandoc -s --metadata title="$title" \
      -t plain <<< "$body" | "$PAGER"
    return 0
  fi
  echo -e "$title\n\n$body" | "$PAGER"
}

# --------------------- completion and delegation --------------------
#         (better than . <(foo bloated_completion) in .bashrc)

_help_title() {
  _filter "$@" && return $?;
  local name="$1"
  while IFS= read -r line; do
    [[ $line =~ ^[:space]*$ ]] && continue
    [[ $line =~ ^#\ (.+) ]] && echo "${BASH_REMATCH[1]}" && return 0
    return 1
  done <<< "${help[$name]}"
}

_have(){ type "$1" &>/dev/null; }

_filter(){
  [[ -n "$1" ]] && return 1
  while IFS= read -ra args; do
    "${FUNCNAME[1]}" "${args[@]}"
  done
}

_buffer() {
  [[ -n "$1" ]] && return 1
  "${FUNCNAME[1]}" "$(</dev/stdin)"
}

while IFS= read -r line; do
  [[ $line =~ ^declare\ -f\ command_ ]] || continue
  COMMANDS+=( "${line##declare -f command_}" )
done < <(declare -F)

if [[ -n $COMP_LINE ]]; then
  line=${COMP_LINE#* }
  for c in "${COMMANDS[@]}"; do
    [[ ${c:0:${#line}} == "${line,,}" && ${c:0:1} != _ ]] && echo "$c"
  done
  exit
fi

for c in "${COMMANDS[@]}"; do
  if [[ $c == "$EXE" ]]; then
    "command_$EXE" "$@"
    exit $?
  fi
done

if [[ -n "$1" ]]; then
  declare cmd="$1"; shift
  for c in "${COMMANDS[@]}"; do
    if [[ $c == "$cmd" ]]; then
      "command_$cmd" "$@"
      exit $?
    fi
  done
fi

command_usage "$@"

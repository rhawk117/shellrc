#!/usr/bin/env bash
# .shellrc.d/.shell_aliases

__has() {
  command -v "$1" >/dev/null 2>&1
}

_RC_FILE="${SHELL_RC_FILE:-}"
_LS_COLOR=""
_BAT_BIN=""

if [[ -z "$_RC_FILE" ]]; then
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    _RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
  else
    _RC_FILE="$HOME/.bashrc"
  fi
fi

# -- rc aliases --
if [[ -n "$_RC_FILE" ]]; then
  alias catrc="cat '$_RC_FILE'"
  alias reload="source '$_RC_FILE'"
fi

alias bashrc='${EDITOR:-nano} "$HOME/.bashrc"'
alias zshrc='${EDITOR:-nano} "${ZDOTDIR:-$HOME}/.zshrc"'

# -- ls aliases --
if command ls --color=auto -d . >/dev/null 2>&1; then
  _LS_COLOR='--color=auto'
elif command ls -G -d . >/dev/null 2>&1; then
  _LS_COLOR='-G'
fi

if [[ -n "$_LS_COLOR" ]]; then
  alias ls="ls $_LS_COLOR"
  alias ll="ls -lah $_LS_COLOR"
  alias la="ls -A $_LS_COLOR"
  alias l="ls -CF $_LS_COLOR"
  alias dir="ls $_LS_COLOR -C"
else
  alias ll='ls -lah'
  alias la='ls -A'
  alias l='ls -CF'
  alias dir='ls -C'
fi

# -- cat/batcat/bat aliases --
if __has bat; then
  _BAT_BIN="bat"
elif __has batcat; then
  _BAT_BIN="batcat"
fi

if [[ -n "$_BAT_BIN" ]]; then
  alias cat="$_BAT_BIN --paging=never"
  alias rawcat='command cat'
  alias ccat="$_BAT_BIN --style=plain --paging=never"
  alias b="$_BAT_BIN"
  alias bn="$_BAT_BIN --paging=never"
  alias bl="$_BAT_BIN --paging=always"
fi

# -- optional aliases --
if __has clip.exe; then
  alias clip='clip.exe'
  alias copy='clip.exe'
elif __has pbcopy; then
  alias clip='pbcopy'
  alias copy='pbcopy'
elif __has wl-copy; then
  alias clip='wl-copy'
  alias copy='wl-copy'
elif __has xclip; then
  alias clip='xclip -selection clipboard'
  alias copy='xclip -selection clipboard'
elif __has xsel; then
  alias clip='xsel --clipboard --input'
  alias copy='xsel --clipboard --input'
elif __has clip; then
  alias copy='clip'
fi

if __has tree; then
  alias tree='tree -C'
fi

if __has ip && command ip -color=auto -V >/dev/null 2>&1; then
  alias ip='ip -color=auto'
fi

if __has less; then
  alias more='less -R'
fi

# -- core aliases --
alias up='cd ..'
alias ..='cd ..'
alias cp='cp -v'
alias mv='mv -v'
alias rm='rm -v'
alias mkdir='mkdir -pv'
alias rmdir='rmdir -v'

if command diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff='diff --color=auto'
fi

# disk
alias df='df -h'
alias du='du -h'

# processes
alias psa='ps aux'
alias psg='ps aux | grep -v grep | grep --color=auto'

# git
if __has git; then
  alias gs='git status --short'
  alias gstatus='git status'
  alias gaa='git add --all'
  alias gc='git checkout'
  alias glog='git log --graph --oneline --decorate'
  alias gpull='git pull'
  alias gpush='git push'
  alias gcommit='git commit -m'
  alias gdiff='git diff'
fi

unset _RC_FILE
unset _LS_COLOR
unset _BAT_BIN
unset -f __has
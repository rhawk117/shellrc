#!/usr/bin/env bash
# .shellrc.d/.shell_env.sh
# common Environment Variables & Configuration Options
# may vary by platform

export EDITOR="${EDITOR:-nano}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--RFXi}"
export GIT_PAGER="${GIT_PAGER:-less -R}"
export MANPAGER="${MANPAGER:-less -R}"
export TERM="${TERM:-xterm-256color}"

export CLICOLOR="${CLICOLOR:-1}"
export CLICOLOR_FORCE="${CLICOLOR_FORCE:-0}"
export GREP_COLORS="${GREP_COLORS:-ms=01;33:mc=01;33:sl=:cx=:fn=35:ln=32:bn=32:se=36}"

export HISTSIZE="${HISTSIZE:-10000}"
export HISTFILESIZE="${HISTFILESIZE:-20000}"

export PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE:-1}"
[[ -f "$HOME/.pythonrc.py" ]] && export PYTHONSTARTUP="$HOME/.pythonrc.py"

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height=80% --border --info=inline --layout=reverse --preview-window=right:60%:wrap}"
export BAT_THEME="${BAT_THEME:-ansi}"
export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-$HOME/.config/ripgrep/config}"


export PATH
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

RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-$HOME/.config/ripgrep/config}"
[[ -f "$RIPGREP_CONFIG_PATH" ]] && export RIPGREP_CONFIG_PATH


export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

export BAT_THEME="${BAT_THEME:-ansi}"
export PATH
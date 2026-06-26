#!/usr/bin/env bash
# /.shellrc.d/.git_bash.sh

__git_branch() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local branch
  branch=$(
    git symbolic-ref --quiet --short HEAD 2>/dev/null ||
    git rev-parse --short HEAD 2>/dev/null
  )
  [[ -n "$branch" ]] && printf ' (%s)' "$branch"
}

set_gitbash_prompt() {
  local branch
  branch="$(__git_branch)"
  local blue='\[\e[1;34m\]'
  local green='\[\e[1;32m\]'
  local red='\[\e[1;31m\]'
  local white='\[\e[1;37m\]'
  local yellow='\[\e[33m\]'
  local dim='\[\e[90m\]'
  local reset='\[\e[0m\]'
  local user_str="${USER:-${LOGNAME:-${USERNAME}}}"
  local host_str="${HOSTNAME%%.*}"
  local path_disp="${PWD/#$HOME/~}"
  local date_str
  date_str="$(date +'%I:%M:%S %p')"
  local cols="${COLUMNS:-80}"
  local left="${user_str}@${host_str} | ${path_disp}${branch} "
  local right=" ${date_str}"
  local fill_len=$(( cols - ${#left} - ${#right} ))
  local filler=""
  if (( fill_len > 0 )); then
    local spaces
    printf -v spaces '%*s' "$fill_len" ''
    filler="${spaces// /·}"
  fi
  PS1="${blue}${user_str}${reset}${dim}@${reset}${green}${host_str}${reset} ${dim}|${reset} ${white}\w${reset}${yellow}${branch}${reset} ${dim}${filler} ${date_str}${reset}"$'\n'"${red}❯${reset} "
}
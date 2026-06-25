#!/usr/bin/env bash

# shared shell entrypoint for:
#   - Windows Git Bash
#   - WSL Ubuntu
#   - Bash
#   - Zsh

# -- directory with files to load --
RC_LIBRARY="$HOME/.shellrc.d"

# -- calculated platform --
SHELL_PLATFORM="unknown"

# -- files to source within RC_LIBRARY --
SHELLRC_FILES=(
  ".shell_utils.sh"
  ".shell_env.sh"
  ".fzf_tools.sh"
)

if [[ -n "${ZSH_VERSION:-}" ]]; then
  RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
else
  RC_FILE="$HOME/.bashrc"
fi


__has() {
  command -v "$1" >/dev/null 2>&1
}


__detect_platform() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*)
      SHELL_PLATFORM="git-bash"
      ;;
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        SHELL_PLATFORM="wsl"
      else
        SHELL_PLATFORM="linux"
      fi
      ;;
    Darwin*)
      SHELL_PLATFORM="macos"
      ;;
    *)
      SHELL_PLATFORM="unknown"
      ;;
  esac
}


__source_shellrc_files() {
  local file
  local file_path

  [[ -d "$RC_LIBRARY" ]] || {
    printf '[error] shell directory not found: %s\n' "$RC_LIBRARY" >&2
    return 1
  }

  for file in "${SHELLRC_FILES[@]}"; do
    [[ -z "$file" ]] && {
      printf '[warn] shellrc file path cannot be empty\n' >&2
      continue
    }

    file_path="$RC_LIBRARY/$file"
    echo "$file_path"

    [[ -e "$file_path" ]] || {
      printf '[warn] shellrc file not found: %s\n' "$file_path" >&2
      continue
    }

    [[ -f "$file_path" ]] || {
      printf '[warn] shellrc file is not a regular file: %s\n' "$file_path" >&2
      continue
    }

    [[ -r "$file_path" ]] || {
      printf '[warn] shellrc file not readable: %s\n' "$file_path" >&2
      continue
    }

    if ! source "$file_path"; then
      printf '[error] shellrc failed to source: %s\n' "$file_path" >&2
    fi
  done
}


__initialize() {
  __detect_platform
  __source_shellrc_files
}


__bootstrap_platform() {
  if [[ "$SHELL_PLATFORM" == "wsl" ]]; then
    export BROWSER="${BROWSER:-wslview}"
    alias explore='explorer.exe .'
    return
  fi

  [[ "$SHELL_PLATFORM" == "git-bash" ]] || {
    return
  }

  export MSYS2_ARG_CONV_EXCL="${MSYS2_ARG_CONV_EXCL:-}"
  alias explore='explorer .'

  if __has clip; then
    alias clpy='clip'
  fi

   __git_branch() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

    local branch
    branch=$(
      git symbolic-ref --quiet --short HEAD 2>/dev/null ||
      git rev-parse --short HEAD 2>/dev/null
    )

    [[ -n "$branch" ]] && printf ' (%s)' "$branch"
  }

  __set_gitbash_prompt() {
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

  export PROMPT_COMMAND=__set_gitbash_prompt

}


__register_optional_aliases() {
  local bat_bin=""

  if __has clip.exe; then
    alias clpy='clip.exe'
  fi

  if __has tree; then
    alias tree='tree -C'
  fi

  if __has ip; then
    alias ip='ip --color=auto'
  fi

  if __has less; then
    alias more='less -R'
  fi

  if __has bat; then
    bat_bin="bat"
  elif __has batcat; then
    bat_bin="batcat"
  fi

  [[ -n "$bat_bin" ]] && {
    alias cat="$bat_bin --paging=never"
    alias rawcat='command cat'
    alias ccat="$bat_bin --style=plain --paging=never"
    alias b="$bat_bin"
    alias bn="$bat_bin --paging=never"
    alias bl="$bat_bin --paging=always"
  }
}


__define_aliases() {
  local ls_color

  if ls --color=auto >/dev/null 2>&1; then
    ls_color='--color=auto'
  else
    ls_color='-G'
  fi

  alias ls="ls $ls_color"
  alias ll="ls -lah $ls_color"
  alias la="ls -A $ls_color"
  alias l="ls -CF $ls_color"
  alias dir="ls $ls_color -C"

  alias up='cd ..'
  alias ..='cd ..'

  alias cp='cp -v'
  alias mv='mv -v'
  alias rm='rm -v'
  alias mkdir='mkdir -pv'
  alias rmdir='rmdir -v'
  alias diff='diff --color=auto'

  # disk
  alias df='df -h'
  alias du='du -h'

  # processes
  alias psa='ps aux'
  alias psg='ps aux | grep -v grep | grep --color=auto'

  # git
  alias gs='git status --short'
  alias gst='git status'
  alias gaa='git add --all'
  alias gc='git checkout'
  alias glog='git log --graph --oneline --decorate'
  alias gpull='git pull'
  alias gps='git push'
  alias gcommit='git commit -m'
  alias gd='git diff'
  alias gds='git diff --staged'
}

unalias catrc editrc reload bashrc zshrc 2>/dev/null || true

catrc() {
  cat "$RC_FILE"
}


editrc() {
  "${EDITOR:-nano}" "$RC_FILE"
}


reload() {
  source "$RC_FILE"
}


bashrc() {
  "${EDITOR:-nano}" "$HOME/.bashrc"
}


zshrc() {
  "${EDITOR:-nano}" "${ZDOTDIR:-$HOME}/.zshrc"
}


__cleanup_namespace() {
  local fn

  for fn in \
    __detect_platform \
    __source_shellrc_files \
    __initialize \
    __bootstrap_platform \
    __register_optional_aliases \
    __define_aliases \
    __main
  do
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      unfunction "$fn" 2>/dev/null || true
    else
      unset -f "$fn" 2>/dev/null || true
    fi
  done

  if [[ "${SHELL_PLATFORM:-}" != "git-bash" ]]; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      unfunction __git_branch __set_gitbash_prompt 2>/dev/null || true
    else
      unset -f __git_branch __set_gitbash_prompt 2>/dev/null || true
    fi
  fi

  unset fn
  unset SHELLRC_FILES

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    unfunction __cleanup_namespace 2>/dev/null || true
  else
    unset -f __cleanup_namespace 2>/dev/null || true
  fi
}


__main() {
  __initialize || return
  __bootstrap_platform
  __register_optional_aliases
  __define_aliases
  export SHELL_PLATFORM
}

__main
__cleanup_namespace
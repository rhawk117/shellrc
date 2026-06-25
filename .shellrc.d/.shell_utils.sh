#!/usr/bin/env bash

# ~/.shellrc.d/.shell_utils.sh

# Exports
# -------
# RC Helpers
#   - rc_debug
#   - rc_info
#   - rc_success
#   - rc_warn
#   - rc_error
#   - rc_fatal
#   - rc_source_safe
# Windows
#   - git_branch
#   - set_ps1
# General
#   - gitsnap
#   - gitfeat
#   - upby
#   - rglob
#   - gr
#   - gri

__BKMARK_PATH=""

if [[ -z "${NO_COLOR:-}" && ( -t 1 || -t 2 ) ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; RESET=""
fi

_log() {
  local color="$1"
  local level="$2"
  local stream="$3"
  shift 3

  if [[ "$stream" == "stderr" ]]; then
    printf "%s[%s]%s %s\n" "$color" "$level" "$RESET" "$*" >&2
  else
    printf "%s[%s]%s %s\n" "$color" "$level" "$RESET" "$*"
  fi
}

rc_debug()   { _log "$MAGENTA" "DEBUG"   stdout "$@"; }
rc_info()    { _log "$BLUE"    "INFO"    stdout "$@"; }
rc_success() { _log "$GREEN"   "SUCCESS" stdout "$@"; }
rc_warn()    { _log "$YELLOW"  "WARN"    stderr "$@"; }
rc_error()   { _log "$RED"     "ERROR"   stderr "$@"; }
rc_fatal()   { _log "$RED"     "FATAL"   stderr "$@"; return 1; }




# gitsnap: add, commit with -m, and optional --pull
unalias gitsnap gitfeat upby rglob gr gri bkmark 2>/dev/null || true

gitsnap() {

  usage() {
    cat <<EOF
Usage: gitsnap [-m <message>] [-s|--sync] [-p|--push]
  -m --message   Commit message (required)

  -s, --sync     Pull changes before committing
  -p, --push     Push changes after committing
  -a, --add      Specify files or directories to add (default: '.')
EOF
  }

  local message=""
  local do_pull=false
  local do_push=false
  local add='.'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;

      -m|--message)
        if [[ -n $2 && ${2:0:1} != "-" ]]; then
          message="$2"
          shift 2
        else
          rc_error "Error: -m requires a commit message"
          return 1
        fi
        ;;


      -s|--sync)
        do_pull=true
        shift 1
        ;;

      -p|--push)
        do_push=true
        shift 1
        ;;

      -a|--add)
        if [[ -n $2 && ${2:0:1} != "-" ]]; then
          add="$2"
          shift 2
        else
          rc_error "Error: -a requires a file or directory to add"
          return 1
        fi
        ;;

      *)
        rc_error "Unknown option: $1" >&2
        return 1
        ;;
    esac
  done


  if $do_pull; then
    git pull || return $?
  fi

  git add "$add" || return $?

  if ! git commit -m "$message"; then
    rc_error "Commit failed. Please check your changes."
    return 1
  fi

  if $do_push; then
    git push || return $?
  fi
}
# gitfeat: create a new branch from a base branch, this helps me always sync local with remote bc i always forget
gitfeat() {
  local new_name=""
  local base_branch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        rc_info "Usage: fcheckout -b <new-branch-name> -r <base-branch>"
        return 0
        ;;
      -b|--branch)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          new_name="$2"
          shift 2
        else
          rc_error "Error: -b/--branch requires a branch name argument"
          return 1
        fi
        ;;
      -r|--base)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          base_branch="$2"
          shift 2
        else
          rc_error "Error: -r/--base requires a base branch argument"
          return 1
        fi
        ;;
      *)
        rc_error "Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [ -z "$new_name" ] || [ -z "$base_branch" ]; then
    rc_error "Both parameters are required"
    rc_info "[usage]: fcheckout -b <new-branch-name> -r <base-branch>"
    return 1
  fi

  git checkout "$base_branch" && git fetch -a
  git checkout -b "$new_name"
  echo "[info] new branch '$new_name' was created from '$base_branch'."
}


upby() {
  for _ in $(seq 1 "$1"); do cd ..; done
}



rglob() {
  local pattern type
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        echo "Usage: rglob <pattern>"
        return 0
        ;;
      -p|--pattern)
        pattern="$2"
        shift 2
        ;;

      -t|--type)
        type="$2"
        shift 2
        ;;

      *)
        break
        ;;
    esac
  done

  type=${type:-f}
  pattern=${pattern:-"$1"}

  [ -z "$pattern" ] && {
    rc_info "Usage: rglob <pattern>"
    return 1
  }

  find . -name "$pattern" -type "$type"
}

gr() {
  grep -rnI --exclude-dir=.git -- "$1" "${2:-.}"
}

gri() {
  grep -rnIi --exclude-dir=.git -- "$1" "${2:-.}"
}



# custom bookmarking of paths
bkmark() {
  do_path() {
    export __BKMARK_PATH="$PWD"
    rc_info "[ ⚐ ] bookmarked: $__BKMARK_PATH"
  }

  do_go() {
    if [[ -z "$__BKMARK_PATH" ]]; then
      rc_error "✗ bookmark unset :("
      return 1
    fi
    cd "$__BKMARK_PATH" || return $?
    rc_info "[ 🕮 ] opening bookmark: $__BKMARK_PATH"
  }

  do_show() {
    echo "${__BKMARK_PATH:-none}"
  }

  if [[ -z "$1" ]]; then
    do_path
    return 0
  fi

  case "$1" in
    path|-p)
      do_path
      ;;
    go|-g)
      do_go
      ;;
    show|-s)
      do_show
      ;;
    *)
      echo "Usage: bkmark {path|go|show}"
      return 1
      ;;
  esac
}
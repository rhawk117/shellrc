#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

REPO_ROOT="$SCRIPT_DIR"
ENTRY_FILE="$REPO_ROOT/.shellrc.sh"
LIB_DIR="$REPO_ROOT/.shellrc.d"

MANAGED_BEGIN="# >>> shellrc managed by $SCRIPT_NAME >>>"
MANAGED_END="# <<< shellrc managed by $SCRIPT_NAME <<<"

DRY_RUN=0
BACKUP=1
TARGETS=()


usage() {
  cat <<EOF
usage: $SCRIPT_NAME <command> [options]

commands:
  install       add/update managed source block
  uninstall     remove managed source block
  status        show install status
  doctor        validate repo layout and rc setup

options:
  --bash        target ~/.bashrc
  --zsh         target ~/.zshrc
  --all         target both bash and zsh
  --dry-run     print actions without writing
  --no-backup   do not create .bak timestamp backup
  -h, --help    show this help

examples:
  ./$SCRIPT_NAME install
  ./$SCRIPT_NAME install --all
  ./$SCRIPT_NAME uninstall --zsh
  ./$SCRIPT_NAME status --all
EOF
}


info() {
  printf '[info] %s\n' "$*"
}


warn() {
  printf '[warn] %s\n' "$*" >&2
}


die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}


shell_quote() {
  local value="$1"
  value=${value//\'/\'\\\'\'}
  printf "'%s'" "$value"
}


rc_file_for_shell() {
  case "$1" in
    bash)
      printf '%s\n' "$HOME/.bashrc"
      ;;
    zsh)
      printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    *)
      die "unsupported shell target: $1"
      ;;
  esac
}


default_target_shell() {
  case "${SHELL##*/}" in
    zsh)
      printf '%s\n' "zsh"
      ;;
    bash)
      printf '%s\n' "bash"
      ;;
    *)
      printf '%s\n' "bash"
      ;;
  esac
}


ensure_repo_layout() {
  [[ -f "$ENTRY_FILE" ]] || {
    die "missing entry file: $ENTRY_FILE"
  }

  [[ -d "$LIB_DIR" ]] || {
    die "missing shellrc directory: $LIB_DIR"
  }
}


make_managed_block() {
  local repo_q
  local entry_q
  local lib_q

  repo_q="$(shell_quote "$REPO_ROOT")"
  entry_q="$(shell_quote "$ENTRY_FILE")"
  lib_q="$(shell_quote "$LIB_DIR")"

  cat <<EOF
$MANAGED_BEGIN
# Source shared shell config from this repo checkout.
export SHELLRC_REPO=$repo_q
export SHELLRC_ENTRY=$entry_q
export SHELLRC_LIBRARY=$lib_q

# Compatibility with .shellrc.sh expecting RC_LIBRARY.
export RC_LIBRARY="\$SHELLRC_LIBRARY"

[[ -r "\$SHELLRC_ENTRY" ]] && source "\$SHELLRC_ENTRY"
$MANAGED_END
EOF
}


has_managed_block() {
  local rc_file="$1"

  [[ -f "$rc_file" ]] || {
    return 1
  }

  grep -Fxq "$MANAGED_BEGIN" "$rc_file"
}


remove_managed_block() {
  local rc_file="$1"
  local out_file="$2"

  awk -v begin="$MANAGED_BEGIN" -v end="$MANAGED_END" '
    $0 == begin {
      skip = 1
      next
    }

    $0 == end {
      skip = 0
      next
    }

    !skip {
      print
    }
  ' "$rc_file" > "$out_file"
}


backup_rc_file() {
  local rc_file="$1"
  local backup_file

  [[ "$BACKUP" -eq 1 ]] || {
    return 0
  }

  [[ -f "$rc_file" ]] || {
    return 0
  }

  backup_file="${rc_file}.bak.$(date +%Y%m%d%H%M%S)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "would backup $rc_file -> $backup_file"
    return 0
  fi

  cp "$rc_file" "$backup_file"
  info "backup created: $backup_file"
}


install_one() {
  local shell_name="$1"
  local rc_file
  local tmp_file
  local out_file

  rc_file="$(rc_file_for_shell "$shell_name")"

  info "installing for $shell_name: $rc_file"

  ensure_repo_layout

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "would ensure rc file exists: $rc_file"
    info "would add/update managed block:"
    make_managed_block
    return 0
  fi

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/shellrc.clean.XXXXXX")"
  out_file="$(mktemp "${TMPDIR:-/tmp}/shellrc.out.XXXXXX")"

  remove_managed_block "$rc_file" "$tmp_file"

  {
    cat "$tmp_file"

    # Ensure one clean gap before the managed block.
    printf '\n'
    make_managed_block
    printf '\n'
  } > "$out_file"

  backup_rc_file "$rc_file"
  mv "$out_file" "$rc_file"
  rm -f "$tmp_file"

  info "installed managed block in $rc_file"
}


uninstall_one() {
  local shell_name="$1"
  local rc_file
  local tmp_file

  rc_file="$(rc_file_for_shell "$shell_name")"

  info "uninstalling for $shell_name: $rc_file"

  [[ -f "$rc_file" ]] || {
    warn "rc file does not exist: $rc_file"
    return 0
  }

  has_managed_block "$rc_file" || {
    info "no managed block found in $rc_file"
    return 0
  }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "would remove managed block from $rc_file"
    return 0
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/shellrc.clean.XXXXXX")"
  remove_managed_block "$rc_file" "$tmp_file"

  backup_rc_file "$rc_file"
  mv "$tmp_file" "$rc_file"

  info "removed managed block from $rc_file"
}


status_one() {
  local shell_name="$1"
  local rc_file

  rc_file="$(rc_file_for_shell "$shell_name")"

  if has_managed_block "$rc_file"; then
    printf '%-5s installed     %s\n' "$shell_name" "$rc_file"
  else
    printf '%-5s not installed %s\n' "$shell_name" "$rc_file"
  fi
}


doctor() {
  local ok=1
  local shell_name
  local rc_file

  printf 'repo root:     %s\n' "$REPO_ROOT"
  printf 'entry file:    %s\n' "$ENTRY_FILE"
  printf 'library dir:   %s\n' "$LIB_DIR"
  printf '\n'

  [[ -f "$ENTRY_FILE" ]] || {
    warn "missing entry file: $ENTRY_FILE"
    ok=0
  }

  [[ -d "$LIB_DIR" ]] || {
    warn "missing library directory: $LIB_DIR"
    ok=0
  }

  for shell_name in "${TARGETS[@]}"; do
    rc_file="$(rc_file_for_shell "$shell_name")"

    if has_managed_block "$rc_file"; then
      printf '%-5s rc block: installed in %s\n' "$shell_name" "$rc_file"
    else
      printf '%-5s rc block: not installed in %s\n' "$shell_name" "$rc_file"
    fi
  done

  if [[ -f "$ENTRY_FILE" ]] && grep -q 'RC_LIBRARY="\$HOME/.shellrc.d"' "$ENTRY_FILE"; then
    warn ".shellrc.sh appears to hardcode RC_LIBRARY to \$HOME/.shellrc.d"
    warn "make it respect SHELLRC_LIBRARY or RC_LIBRARY, shown below"
    ok=0
  fi

  [[ "$ok" -eq 1 ]] || {
    return 1
  }

  info "doctor passed"
}


parse_args() {
  local arg

  COMMAND="${1:-install}"

  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  while [[ "$#" -gt 0 ]]; do
    arg="$1"

    case "$arg" in
      --bash)
        TARGETS+=("bash")
        ;;
      --zsh)
        TARGETS+=("zsh")
        ;;
      --all)
        TARGETS=("bash" "zsh")
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --no-backup)
        BACKUP=0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $arg"
        ;;
    esac

    shift
  done

  if [[ "${#TARGETS[@]}" -eq 0 ]]; then
    TARGETS=("$(default_target_shell)")
  fi
}


main() {
  local shell_name

  parse_args "$@"

  case "$COMMAND" in
    install)
      for shell_name in "${TARGETS[@]}"; do
        install_one "$shell_name"
      done
      ;;
    uninstall)
      for shell_name in "${TARGETS[@]}"; do
        uninstall_one "$shell_name"
      done
      ;;
    status)
      for shell_name in "${TARGETS[@]}"; do
        status_one "$shell_name"
      done
      ;;
    doctor)
      doctor
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "unknown command: $COMMAND"
      ;;
  esac
}


main "$@"
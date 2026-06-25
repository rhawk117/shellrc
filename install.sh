#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

REPO_ROOT="$SCRIPT_DIR"

SOURCE_ENTRY_FILE="$REPO_ROOT/.shellrc.sh"
SOURCE_LIB_DIR="$REPO_ROOT/.shellrc.d"

INSTALL_ENTRY_FILE="$HOME/.shellrc.sh"
INSTALL_LIB_DIR="$HOME/.shellrc.d"

MANAGED_BEGIN="# >>> shellrc managed by $SCRIPT_NAME >>>"
MANAGED_END="# <<< shellrc managed by $SCRIPT_NAME <<<"

DRY_RUN=0
BACKUP=1
PURGE=0
TARGETS=()


usage() {
  cat <<EOF
usage: $SCRIPT_NAME <command> [options]

commands:
  install       copy shellrc files into HOME and add/update managed rc block
  uninstall     remove managed rc block
  status        show install status
  doctor        validate repo layout, installed files, and rc setup

options:
  --bash        target ~/.bashrc
  --zsh         target ~/.zshrc
  --all         target both bash and zsh
  --purge       with uninstall, also remove ~/.shellrc.sh and ~/.shellrc.d
  --dry-run     print actions without writing
  --no-backup   do not create .bak timestamp backups
  -h, --help    show this help

examples:
  ./$SCRIPT_NAME install
  ./$SCRIPT_NAME install --all
  ./$SCRIPT_NAME uninstall --zsh
  ./$SCRIPT_NAME uninstall --all --purge
  ./$SCRIPT_NAME status --all
  ./$SCRIPT_NAME doctor --all
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
  [[ -f "$SOURCE_ENTRY_FILE" ]] || {
    die "missing source entry file: $SOURCE_ENTRY_FILE"
  }

  [[ -d "$SOURCE_LIB_DIR" ]] || {
    die "missing source shellrc directory: $SOURCE_LIB_DIR"
  }
}


backup_path() {
  local path="$1"
  local backup_path

  [[ "$BACKUP" -eq 1 ]] || {
    return 0
  }

  [[ -e "$path" ]] || {
    return 0
  }

  backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "would backup $path -> $backup_path"
    return 0
  fi

  cp -R "$path" "$backup_path"
  info "backup created: $backup_path"
}


install_shellrc_assets() {
  local tmp_entry
  local tmp_lib

  ensure_repo_layout

  info "installing shellrc assets into HOME"
  info "source entry: $SOURCE_ENTRY_FILE"
  info "source dir:   $SOURCE_LIB_DIR"
  info "target entry: $INSTALL_ENTRY_FILE"
  info "target dir:   $INSTALL_LIB_DIR"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "would copy $SOURCE_ENTRY_FILE -> $INSTALL_ENTRY_FILE"
    info "would copy $SOURCE_LIB_DIR -> $INSTALL_LIB_DIR"
    return 0
  fi

  tmp_entry="$(mktemp "${TMPDIR:-/tmp}/shellrc.entry.XXXXXX")"
  tmp_lib="$(mktemp -d "${TMPDIR:-/tmp}/shellrc.d.XXXXXX")"

  cp "$SOURCE_ENTRY_FILE" "$tmp_entry"
  cp -R "$SOURCE_LIB_DIR"/. "$tmp_lib"/

  backup_path "$INSTALL_ENTRY_FILE"
  backup_path "$INSTALL_LIB_DIR"

  rm -f "$INSTALL_ENTRY_FILE"
  rm -rf "$INSTALL_LIB_DIR"

  mv "$tmp_entry" "$INSTALL_ENTRY_FILE"
  mv "$tmp_lib" "$INSTALL_LIB_DIR"

  info "installed $INSTALL_ENTRY_FILE"
  info "installed $INSTALL_LIB_DIR"
}


make_managed_block() {
  local repo_q
  local entry_q
  local lib_q

  repo_q="$(shell_quote "$REPO_ROOT")"
  entry_q="$(shell_quote "$INSTALL_ENTRY_FILE")"
  lib_q="$(shell_quote "$INSTALL_LIB_DIR")"

  cat <<EOF
$MANAGED_BEGIN
# Source installed shared shell config.
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


install_one() {
  local shell_name="$1"
  local rc_file
  local tmp_file
  local out_file

  rc_file="$(rc_file_for_shell "$shell_name")"

  info "installing rc block for $shell_name: $rc_file"

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
    printf '\n'
    make_managed_block
    printf '\n'
  } > "$out_file"

  backup_path "$rc_file"

  mv "$out_file" "$rc_file"
  rm -f "$tmp_file"

  info "installed managed block in $rc_file"
}


uninstall_one() {
  local shell_name="$1"
  local rc_file
  local tmp_file

  rc_file="$(rc_file_for_shell "$shell_name")"

  info "uninstalling rc block for $shell_name: $rc_file"

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

  backup_path "$rc_file"

  mv "$tmp_file" "$rc_file"

  info "removed managed block from $rc_file"
}


purge_installed_assets() {
  info "purging installed shellrc assets from HOME"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "would remove $INSTALL_ENTRY_FILE"
    info "would remove $INSTALL_LIB_DIR"
    return 0
  fi

  backup_path "$INSTALL_ENTRY_FILE"
  backup_path "$INSTALL_LIB_DIR"

  rm -f "$INSTALL_ENTRY_FILE"
  rm -rf "$INSTALL_LIB_DIR"

  info "removed $INSTALL_ENTRY_FILE"
  info "removed $INSTALL_LIB_DIR"
}


status_one() {
  local shell_name="$1"
  local rc_file

  rc_file="$(rc_file_for_shell "$shell_name")"

  if has_managed_block "$rc_file"; then
    printf '%-5s rc block: installed     %s\n' "$shell_name" "$rc_file"
  else
    printf '%-5s rc block: not installed %s\n' "$shell_name" "$rc_file"
  fi
}


status_assets() {
  if [[ -f "$INSTALL_ENTRY_FILE" ]]; then
    printf 'entry installed: yes %s\n' "$INSTALL_ENTRY_FILE"
  else
    printf 'entry installed: no  %s\n' "$INSTALL_ENTRY_FILE"
  fi

  if [[ -d "$INSTALL_LIB_DIR" ]]; then
    printf 'dir installed:   yes %s\n' "$INSTALL_LIB_DIR"
  else
    printf 'dir installed:   no  %s\n' "$INSTALL_LIB_DIR"
  fi
}


doctor() {
  local ok=1
  local shell_name
  local rc_file

  printf 'repo root:       %s\n' "$REPO_ROOT"
  printf 'source entry:    %s\n' "$SOURCE_ENTRY_FILE"
  printf 'source dir:      %s\n' "$SOURCE_LIB_DIR"
  printf 'installed entry: %s\n' "$INSTALL_ENTRY_FILE"
  printf 'installed dir:   %s\n' "$INSTALL_LIB_DIR"
  printf '\n'

  [[ -f "$SOURCE_ENTRY_FILE" ]] || {
    warn "missing source entry file: $SOURCE_ENTRY_FILE"
    ok=0
  }

  [[ -d "$SOURCE_LIB_DIR" ]] || {
    warn "missing source shellrc directory: $SOURCE_LIB_DIR"
    ok=0
  }

  [[ -f "$INSTALL_ENTRY_FILE" ]] || {
    warn "installed entry file missing: $INSTALL_ENTRY_FILE"
    ok=0
  }

  [[ -d "$INSTALL_LIB_DIR" ]] || {
    warn "installed shellrc directory missing: $INSTALL_LIB_DIR"
    ok=0
  }

  for shell_name in "${TARGETS[@]}"; do
    rc_file="$(rc_file_for_shell "$shell_name")"

    if has_managed_block "$rc_file"; then
      printf '%-5s rc block: installed in %s\n' "$shell_name" "$rc_file"
    else
      printf '%-5s rc block: not installed in %s\n' "$shell_name" "$rc_file"
      ok=0
    fi
  done

  if [[ -f "$INSTALL_ENTRY_FILE" ]] && grep -q 'RC_LIBRARY="\$HOME/.shellrc.d"' "$INSTALL_ENTRY_FILE"; then
    warn "$INSTALL_ENTRY_FILE appears to hardcode RC_LIBRARY"
    warn "prefer: RC_LIBRARY=\"\${RC_LIBRARY:-\${SHELLRC_LIBRARY:-\$HOME/.shellrc.d}}\""
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
      --purge)
        PURGE=1
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
      install_shellrc_assets

      for shell_name in "${TARGETS[@]}"; do
        install_one "$shell_name"
      done
      ;;
    uninstall)
      for shell_name in "${TARGETS[@]}"; do
        uninstall_one "$shell_name"
      done

      if [[ "$PURGE" -eq 1 ]]; then
        purge_installed_assets
      fi
      ;;
    status)
      status_assets

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
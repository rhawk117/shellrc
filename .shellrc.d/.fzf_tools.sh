#!/usr/bin/env bash

# fzf shell helpers
#
# Requires:
#   fzf
#
# Optional:
#   bat, code, lsof, pstree, pwdx


__fz_has() {
  command -v "$1" >/dev/null 2>&1
}

__fz_err() {
  printf 'Error: %s\n' "$*" >&2
}

__fz_require() {
  local missing=0

  for cmd in "$@"; do
    if ! __fz_has "$cmd"; then
      __fz_err "Missing required command: $cmd"
      missing=1
    fi
  done

  return "$missing"
}

__fz_file_preview() {
  local path="$1"
  local lines="${2:-50}"

  if [[ -d "$path" ]]; then
    ls -lah "$path" 2>/dev/null
    return
  fi

  if [[ ! -f "$path" ]]; then
    echo "Cannot preview: $path"
    return
  fi

  if __fz_has bat; then
    bat --style=numbers --color=always --line-range ":$lines" "$path" 2>/dev/null
  else
    head -n "$lines" "$path" 2>/dev/null
  fi
}

__fz_select_file() {
  local prompt="${1:-Select file: }"
  local lines="${2:-50}"
  local root="${3:-.}"

  find "$root" -type f 2>/dev/null |
    fzf \
      --height=80% \
      --border \
      --info=inline \
      --prompt="$prompt" \
      --preview="__fz_file_preview {} $lines" \
      --preview-window=right:60%:wrap
}

__fz_copy() {
  if __fz_has clip; then
    clip
  elif __fz_has pbcopy; then
    pbcopy
  elif __fz_has wl-copy; then
    wl-copy
  elif __fz_has xclip; then
    xclip -selection clipboard
  elif __fz_has xsel; then
    xsel --clipboard --input
  else
    __fz_err "No clipboard command found: clip, pbcopy, wl-copy, xclip, or xsel"
    return 1
  fi
}

__fz_open_at_line() {
  local file="$1"
  local line="${2:-1}"
  local editor="${3:-nano}"

  [[ -f "$file" ]] || {
    __fz_err "File not found: $file"
    return 1
  }

  case "$editor" in
    vs|vscode|code)
      if ! __fz_has code; then
        __fz_err "VS Code CLI not found: code"
        return 1
      fi
      code -g "$file:$line"
      ;;
    nano)
      nano +"$line" "$file"
      ;;
    *)
      "$editor" +"$line" "$file"
      ;;
  esac
}

if [[ -z "${ZSH_VERSION:-}" ]]; then
  export -f __fz_has
  export -f __fz_err
  export -f __fz_file_preview
  export -f __fz_open_at_line
fi

unalias fzls fzinfo fzcomp fzcd fzclip fzvs fzless fzmore fznano fzdiff fzh fzgc fzgrep fzg fzps fzhelp 2>/dev/null || true

fzls() {
  usage() {
    cat <<'EOF'
Usage:
  fzls [options] [pattern]

Find files, directories, or symlinks with fzf and preview their content.

Options:
  -h, --help              Show this help message
  -t, --type TYPE         Match type: f=file, d=directory, l=symlink
  -d, --dir DIR           Directory to search in
      --directory DIR     Same as --dir
  -n, --name PATTERN      Name pattern to match
  -l, --lines N           Number of preview lines
  -a, --all               Include hidden files and directories

Examples:
  fzls
  fzls '*.py'
  fzls -n '*.py'
  fzls -a -n '.*'
  fzls -t d
  fzls -d ./backend -n '*.sql'
EOF
  }

  local name="*"
  local type="f"
  local directory="$PWD"
  local lines=20
  local include_hidden=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      -n|--name)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a pattern"; usage; return 1; }
        name="$2"
        shift 2
        ;;
      -t|--type)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a type"; usage; return 1; }
        type="$2"
        shift 2
        ;;
      -d|--dir|--directory)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a directory"; usage; return 1; }
        directory="$2"
        shift 2
        ;;
      -l|--lines)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a number"; usage; return 1; }
        lines="$2"
        shift 2
        ;;
      -a|--all)
        include_hidden=true
        shift
        ;;
      -*)
        __fz_err "Unknown option: $1"
        usage
        return 1
        ;;
      *)
        name="$1"
        shift
        ;;
    esac
  done

  __fz_require fzf find || return 1

  [[ -d "$directory" ]] || {
    __fz_err "Directory does not exist: $directory"
    return 1
  }

  local find_args=("$directory")

  if [[ "$include_hidden" == false ]]; then
    find_args+=("!" -path "*/.*")
  fi

  find_args+=(-type "$type" -name "$name")

  find "${find_args[@]}" 2>/dev/null |
    fzf -m \
      --height=80% \
      --border \
      --info=inline \
      --header="Select entries. Preview: first $lines lines" \
      --preview="__fz_file_preview {} $lines" \
      --preview-window=right:55%:border-left:wrap
}


fzinfo() {
  usage() {
    cat <<'EOF'
Usage:
  fzinfo [options]

Find files, directories, or symlinks and preview metadata.

Options:
  -h, --help              Show this help message
  -t, --type TYPE         Match type: f=file, d=directory, l=symlink
  -d, --dir DIR           Directory to search in
      --directory DIR     Same as --dir
  -n, --name PATTERN      Name pattern to match

Examples:
  fzinfo
  fzinfo -n '*.py'
  fzinfo -t d
  fzinfo -d ./backend
EOF
  }

  local name="*"
  local type="f"
  local directory="$PWD"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      -n|--name)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a pattern"; usage; return 1; }
        name="$2"
        shift 2
        ;;
      -t|--type)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a type"; usage; return 1; }
        type="$2"
        shift 2
        ;;
      -d|--dir|--directory)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a directory"; usage; return 1; }
        directory="$2"
        shift 2
        ;;
      -*)
        __fz_err "Unknown option: $1"
        usage
        return 1
        ;;
      *)
        __fz_err "Unknown argument: $1"
        usage
        return 1
        ;;
    esac
  done

  __fz_require fzf find || return 1

  [[ -d "$directory" ]] || {
    __fz_err "Directory does not exist: $directory"
    return 1
  }

  find "$directory" -type "$type" -name "$name" 2>/dev/null |
    fzf -m \
      --height=80% \
      --border \
      --info=inline \
      --header="Select entries. Preview: file info" \
      --preview="
        echo '=== Path ==='
        echo {}
        echo
        echo '=== Permissions & Size ==='
        ls -lah {} 2>/dev/null
        echo
        echo '=== File Type ==='
        file {} 2>/dev/null
        echo
        echo '=== Statistics ==='
        stat {} 2>/dev/null
      " \
      --preview-window=right:60%:border-left:wrap
}


fzcomp() {
  usage() {
    cat <<'EOF'
Usage:
  fzcomp

Fuzzy-search available shell commands and preview their shell type.

Examples:
  fzcomp
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf compgen || return 1

  compgen -c |
    sort -u |
    fzf \
      --height=70% \
      --border \
      --info=inline \
      --header="Select a command" \
      --preview="type {} 2>/dev/null || command -v {} 2>/dev/null" \
      --preview-window=right:50%:border-left:wrap
}


fzcd() {
  usage() {
    cat <<'EOF'
Usage:
  fzcd [directory]

Fuzzy-select a directory and cd into it.

Examples:
  fzcd
  fzcd ./backend
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
  esac

  __fz_require fzf find || return 1

  local root="${1:-.}"
  local dir

  [[ -d "$root" ]] || {
    __fz_err "Directory does not exist: $root"
    return 1
  }

  dir=$(
    find "$root" -type d 2>/dev/null |
      fzf \
        --height=70% \
        --border \
        --info=inline \
        --prompt="Directory: " \
        --preview="ls -lah {} 2>/dev/null" \
        --preview-window=right:50%:wrap
  )

  [[ -n "$dir" ]] || return 0
  cd "$dir" || __fz_err "Failed to cd into: $dir"
}


fzclip() {
  usage() {
    cat <<'EOF'
Usage:
  fzclip

Read stdin through fzf and copy the selected line to the clipboard.

Examples:
  history | fzclip
  find . -type f | fzclip
  printf '%s\n' one two three | fzclip
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf || return 1

  local selection
  selection=$(fzf --height=50% --border --info=inline --prompt="Copy: ")

  if [[ -n "$selection" ]]; then
    printf '%s' "$selection" | __fz_copy
    printf 'Copied: %s\n' "$selection"
  else
    echo "No selection made."
  fi
}


fzvs() {
  usage() {
    cat <<'EOF'
Usage:
  fzvs [options]

Open a fuzzy-selected directory or file in VS Code.

Options:
  -h, --help              Show this help message
  -f, --files             Search files instead of directories
  -d, --dir DIR           Directory to search in
      --directory DIR     Same as --dir

Examples:
  fzvs
  fzvs --files
  fzvs --files -d ./backend
EOF
  }

  local target_type="d"
  local directory="."
  local prompt="Directory for VS Code: "

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      -f|--files)
        target_type="f"
        prompt="File for VS Code: "
        shift
        ;;
      -d|--dir|--directory)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a directory"; usage; return 1; }
        directory="$2"
        shift 2
        ;;
      -*)
        __fz_err "Unknown option: $1"
        usage
        return 1
        ;;
      *)
        __fz_err "Unknown argument: $1"
        usage
        return 1
        ;;
    esac
  done

  __fz_require fzf find code || return 1

  [[ -d "$directory" ]] || {
    __fz_err "Directory does not exist: $directory"
    return 1
  }

  local target
  target=$(
    find "$directory" -type "$target_type" 2>/dev/null |
      fzf \
        --height=80% \
        --border \
        --info=inline \
        --prompt="$prompt" \
        --preview="__fz_file_preview {} 60" \
        --preview-window=right:60%:wrap
  )

  [[ -n "$target" ]] || return 0
  code "$target"
}


fzless() {
  usage() {
    cat <<'EOF'
Usage:
  fzless

Fuzzy-select a file and open it with less.

Examples:
  fzless
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf find less || return 1

  local file
  file=$(__fz_select_file "File for less: " 80)
  [[ -n "$file" ]] && less "$file"
}

fzmore() {
  usage() {
    cat <<'EOF'
Usage:
  fzmore

Fuzzy-select a file and open it with more.

Examples:
  fzmore
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf find more || return 1

  local file
  file=$(__fz_select_file "File for more: " 80)
  [[ -n "$file" ]] && more "$file"
}

fznano() {
  usage() {
    cat <<'EOF'
Usage:
  fznano

Fuzzy-select a file and open it in nano.

Examples:
  fznano
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf find nano || return 1

  local file
  file=$(__fz_select_file "File for nano: " 80)

  if [[ -n "$file" ]]; then
    nano "$file"
  else
    echo "No file selected."
  fi
}


fzdiff() {
  usage() {
    cat <<'EOF'
Usage:
  fzdiff <reference_file>

Fuzzy-select another file and diff it against <reference_file>.

Examples:
  fzdiff pyproject.toml
  fzdiff ./backend/models.py
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
  esac

  __fz_require fzf find diff || return 1

  local reference_file="${1:-}"
  local selected_file

  [[ -n "$reference_file" ]] || {
    usage
    return 1
  }

  [[ -f "$reference_file" ]] || {
    __fz_err "Reference file not found: $reference_file"
    return 1
  }

  selected_file=$(
    find . -type f -not -path '*/.*' 2>/dev/null |
      fzf \
        --height=90% \
        --border \
        --info=inline \
        --prompt="Compare with $reference_file: " \
        --preview="diff --color=always -u '$reference_file' {} 2>/dev/null || echo 'Files are identical or binary'" \
        --preview-window=right:80%:wrap
  )

  [[ -n "$selected_file" ]] || return 0
  diff -u "$reference_file" "$selected_file"
}


fzh() {
  usage() {
    cat <<'EOF'
Usage:
  fzh

Fuzzy-search shell history, print the selected command, then execute it.

Examples:
  fzh
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf || return 1

  local cmd
  cmd=$(
    history |
      sort -k1,1nr |
      sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
      fzf \
        --height=50% \
        --border \
        --info=inline \
        --prompt="History: " \
        --no-preview
  )

  [[ -n "$cmd" ]] || return 0
  echo "$cmd"
  eval "$cmd"
}


fzgc() {
  usage() {
    cat <<'EOF'
Usage:
  fzgc

Fuzzy-select a local or remote Git branch and check it out.

Examples:
  fzgc
  fzhelp fzgc
EOF
  }

  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      __fz_err "Unknown argument: $1"
      usage
      return 1
      ;;
  esac

  __fz_require fzf git || return 1

  git rev-parse --git-dir >/dev/null 2>&1 || {
    __fz_err "Not inside a Git repository"
    return 1
  }

  local branch
  branch=$(
    git for-each-ref \
      --format='%(refname:short)' \
      refs/heads refs/remotes 2>/dev/null |
      sed 's#^origin/##' |
      grep -v 'HEAD$' |
      sort -u |
      fzf \
        --height=60% \
        --border \
        --info=inline \
        --prompt="Git checkout: " \
        --preview="git log --oneline --decorate --graph --color=always {} -- 2>/dev/null | head -80" \
        --preview-window=right:60%:wrap
  ) || return

  [[ -n "$branch" ]] || return 0
  git checkout "$branch"
}


__fzgrep_preview() {
  local file="$1"
  local line="${2:-1}"
  local before="${3:-20}"
  local after="${4:-30}"

  [[ -f "$file" ]] || {
    echo "Cannot preview: $file"
    return
  }

  local start=$(( line - before ))
  local end=$(( line + after ))
  (( start < 1 )) && start=1

  local section
  section=$(
    awk -v line="$line" '
      NR > line { exit }

      /^[[:space:]]{0,3}#{1,6}[[:space:]]/ {
        hit = NR ": " $0
      }

      /^[[:space:]]*(class|def|async def|function)[[:space:]]+/ {
        hit = NR ": " $0
      }

      /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
        hit = NR ": " $0
      }

      END {
        if (hit) print hit
        else print "No obvious section header found"
      }
    ' "$file" 2>/dev/null
  )

  printf 'File: %s\n' "$file"
  printf 'Match line: %s\n' "$line"
  printf 'Section: %s\n' "$section"
  printf '%s\n\n' '────────────────────────────────────────'

  if __fz_has bat; then
    bat \
      --style=numbers \
      --color=always \
      --highlight-line "$line" \
      --line-range "$start:$end" \
      "$file" 2>/dev/null
  else
    awk -v start="$start" -v end="$end" -v hit="$line" '
      NR >= start && NR <= end {
        marker = (NR == hit) ? ">" : " "
        printf "%s %6d | %s\n", marker, NR, $0
      }
    ' "$file" 2>/dev/null
  fi
}

if [[ -z "${ZSH_VERSION:-}" ]]; then
  export -f __fzgrep_preview
fi

fzgrep() {
  usage() {
    cat <<'EOF'
Usage:
  fzgrep [options] <pattern> [directory]

Recursive grep with fzf preview. Selecting a match opens the file at the match line.

Options:
  -h, --help              Show this help message
  -i, --ignore-case       Case-insensitive search
  -d, --dir DIR           Directory to search in
      --directory DIR     Same as --dir
  --vs                    Open selection in VS Code instead of nano
  --hidden                Include hidden file names
  --no-ignore-git         Search inside .git too, because chaos apparently has fans

Examples:
  fzgrep "TODO"
  fzgrep "UserRole" ./backend
  fzgrep -i "login" .
  fzgrep --vs "Permission" ./backend
  fzg "def login" .
EOF
  }

  local pattern=""
  local directory="."
  local editor="nano"
  local ignore_case=false
  local include_hidden=false
  local ignore_git=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      -i|--ignore-case)
        ignore_case=true
        shift
        ;;
      -d|--dir|--directory)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a directory"; usage; return 1; }
        directory="$2"
        shift 2
        ;;
      --vs)
        editor="vs"
        shift
        ;;
      --hidden)
        include_hidden=true
        shift
        ;;
      --no-ignore-git)
        ignore_git=false
        shift
        ;;
      -*)
        __fz_err "Unknown option: $1"
        usage
        return 1
        ;;
      *)
        if [[ -z "$pattern" ]]; then
          pattern="$1"
        else
          directory="$1"
        fi
        shift
        ;;
    esac
  done

  __fz_require fzf grep || return 1

  [[ -n "$pattern" ]] || {
    usage
    return 1
  }

  [[ -d "$directory" ]] || {
    __fz_err "Directory does not exist: $directory"
    return 1
  }

  local grep_args=(-RInH -I)

  if [[ "$ignore_case" == true ]]; then
    grep_args+=(-i)
  fi

  if [[ "$ignore_git" == true ]]; then
    grep_args+=(--exclude-dir=.git)
  fi

  if [[ "$include_hidden" == false ]]; then
    grep_args+=(--exclude='.*')
  fi

  local selected
  selected=$(
    grep "${grep_args[@]}" -- "$pattern" "$directory" 2>/dev/null |
      fzf \
        --ansi \
        --height=90% \
        --border \
        --info=inline \
        --delimiter=':' \
        --with-nth=1,2,3.. \
        --prompt="grep: " \
        --header="Enter selects. Preview shows nearest section header and match context." \
        --preview="__fzgrep_preview {1} {2}" \
        --preview-window=right:65%:border-left:wrap
  )

  [[ -n "$selected" ]] || return 0

  local file line
  file="${selected%%:*}"
  line="${selected#*:}"
  line="${line%%:*}"

  __fz_open_at_line "$file" "$line" "$editor"
}

fzg() {
  fzgrep "$@"
}


__fzps_sort_arg() {
  case "$1" in
    pid) echo "pid" ;;
    ppid) echo "ppid" ;;
    user) echo "user" ;;
    cpu) echo "-%cpu" ;;
    mem) echo "-%mem" ;;
    time) echo "-etime" ;;
    cmd|command|comm) echo "comm" ;;
    *) echo "-%cpu" ;;
  esac
}

__fzps_list() {
  local sort="${1:-cpu}"
  local user_filter="${2:-}"
  local sort_arg

  sort_arg="$(__fzps_sort_arg "$sort")"

  if [[ -n "$user_filter" ]]; then
    ps -u "$user_filter" \
      -o pid=,ppid=,user=,stat=,%cpu=,%mem=,etime=,comm=,args= \
      --sort="$sort_arg" 2>/dev/null |
      awk 'BEGIN {
        printf "%-8s %-8s %-12s %-8s %-6s %-6s %-12s %-24s %s\n", "PID", "PPID", "USER", "STAT", "CPU", "MEM", "ELAPSED", "COMMAND", "ARGS"
      } { print }'
  else
    ps -eo pid=,ppid=,user=,stat=,%cpu=,%mem=,etime=,comm=,args= \
      --sort="$sort_arg" 2>/dev/null |
      awk 'BEGIN {
        printf "%-8s %-8s %-12s %-8s %-6s %-6s %-12s %-24s %s\n", "PID", "PPID", "USER", "STAT", "CPU", "MEM", "ELAPSED", "COMMAND", "ARGS"
      } { print }'
  fi
}

__fzps_preview() {
  local pid="$1"

  [[ "$pid" =~ ^[0-9]+$ ]] || {
    echo "Select a process to preview details"
    return
  }

  echo "=== Process ==="
  ps -p "$pid" -o pid,ppid,user,stat,%cpu,%mem,etime,lstart,comm,args 2>/dev/null || {
    echo "Process no longer exists: $pid"
    return
  }

  echo
  echo "=== Tree Context ==="
  if __fz_has pstree; then
    pstree -aps "$pid" 2>/dev/null
  else
    ps -f --forest -p "$pid" 2>/dev/null || ps -fp "$pid" 2>/dev/null
  fi

  echo
  echo "=== Working Directory ==="
  if __fz_has pwdx; then
    pwdx "$pid" 2>/dev/null
  elif [[ -e "/proc/$pid/cwd" ]]; then
    readlink "/proc/$pid/cwd" 2>/dev/null
  else
    echo "Working directory unavailable"
  fi

  echo
  echo "=== Open Files ==="
  if __fz_has lsof; then
    lsof -p "$pid" 2>/dev/null | head -40
  else
    echo "lsof not installed"
  fi

  echo
  echo "=== Environment Preview ==="
  if [[ -r "/proc/$pid/environ" ]]; then
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | head -40
  else
    echo "Environment unavailable"
  fi
}

if [[ -z "${ZSH_VERSION:-}" ]]; then
  export -f __fzps_sort_arg
  export -f __fzps_list
  export -f __fzps_preview
fi

fzps() {
  usage() {
    cat <<'EOF'
Usage:
  fzps [options]

Interactive process browser with sortable fzf list and side-panel process details.

Options:
  -h, --help              Show this help message
  -s, --sort FIELD        Initial sort field
                          fields: cpu, mem, pid, ppid, user, time, cmd
  -u, --user USER         Show processes for one user
  --pid-only              Print only the selected PID
  --cmd-only              Print only the selected command/args

Interactive keys:
  ctrl-p                  Sort by PID
  ctrl-o                  Sort by PPID
  ctrl-u                  Sort by user
  ctrl-c                  Sort by CPU descending
  ctrl-m                  Sort by memory descending
  ctrl-t                  Sort by elapsed time
  ctrl-a                  Sort by command
  enter                   Select process

Examples:
  fzps
  fzps --sort mem
  fzps -s cpu
  fzps -u "$USER"
  fzps --pid-only
  kill "$(fzps --pid-only)"
EOF
  }

  local sort="cpu"
  local user_filter=""
  local output_mode="full"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      -s|--sort)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a sort field"; usage; return 1; }
        sort="$2"
        shift 2
        ;;
      -u|--user)
        [[ -n "${2:-}" ]] || { __fz_err "$1 requires a username"; usage; return 1; }
        user_filter="$2"
        shift 2
        ;;
      --pid-only)
        output_mode="pid"
        shift
        ;;
      --cmd-only)
        output_mode="cmd"
        shift
        ;;
      -*)
        __fz_err "Unknown option: $1"
        usage
        return 1
        ;;
      *)
        __fz_err "Unknown argument: $1"
        usage
        return 1
        ;;
    esac
  done

  __fz_require fzf ps || return 1

  local selected
  selected=$(
    __fzps_list "$sort" "$user_filter" |
      fzf \
        --height=90% \
        --border \
        --info=inline \
        --ansi \
        --no-sort \
        --header-lines=1 \
        --prompt="processes [$sort]: " \
        --preview="__fzps_preview {1}" \
        --preview-window=right:65%:border-left:wrap \
        --bind="ctrl-p:reload(__fzps_list pid '$user_filter')+change-prompt(processes [pid]: )" \
        --bind="ctrl-o:reload(__fzps_list ppid '$user_filter')+change-prompt(processes [ppid]: )" \
        --bind="ctrl-u:reload(__fzps_list user '$user_filter')+change-prompt(processes [user]: )" \
        --bind="ctrl-c:reload(__fzps_list cpu '$user_filter')+change-prompt(processes [cpu]: )" \
        --bind="ctrl-m:reload(__fzps_list mem '$user_filter')+change-prompt(processes [mem]: )" \
        --bind="ctrl-t:reload(__fzps_list time '$user_filter')+change-prompt(processes [time]: )" \
        --bind="ctrl-a:reload(__fzps_list cmd '$user_filter')+change-prompt(processes [cmd]: )"
  )

  [[ -n "$selected" ]] || return 0

  local pid cmd
  pid="$(awk '{print $1}' <<< "$selected")"
  cmd="$(awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; sub(/^[[:space:]]+/, ""); print}' <<< "$selected")"

  case "$output_mode" in
    pid) printf '%s\n' "$pid" ;;
    cmd) printf '%s\n' "$cmd" ;;
    *) printf '%s\n' "$selected" ;;
  esac
}


fzhelp() {
  local cmd="${1:-}"

  if [[ -n "$cmd" ]]; then
    case "$cmd" in
      fzls|fzinfo|fzcomp|fzcd|fzclip|fzvs|fzless|fzmore|fzdiff|fzh|fznano|fzgc|fzgrep|fzg|fzps)
        "$cmd" --help
        ;;
      *)
        __fz_err "Unknown fuzzy command: $cmd"
        echo "Run: fzhelp"
        return 1
        ;;
    esac
    return
  fi

  cat <<'EOF'
[Fuzzy Finder Commands]

File discovery:
  fzls        Find files/directories/symlinks and preview contents
  fzinfo      Find files/directories/symlinks and preview metadata
  fzgrep      Recursive grep with preview and open-at-line
  fzg         Short alias/function for fzgrep

Opening files:
  fznano      Select a file and open in nano
  fzless      Select a file and open in less
  fzmore      Select a file and open in more
  fzvs        Select a file or directory and open in VS Code

Navigation:
  fzcd        Select a directory and cd into it

Git:
  fzgc        Select a Git branch and check it out

Processes:
  fzps        Browse processes with sortable fzf list and side-panel details

Shell:
  fzcomp      Browse available shell commands
  fzh         Search shell history and execute selected command
  fzclip      Copy a fuzzy-selected stdin line to clipboard

Diff:
  fzdiff      Compare a selected file against a reference file

Help:
  fzhelp              Show this overview
  fzhelp <command>    Show usage for one command

Examples:
  fzhelp fzgc
  fzhelp fzgrep
  fzhelp fzps

  fzgrep "TODO" .
  fzgrep --vs "UserRole" ./backend
  fzg -i "permission" .

  fzps
  fzps --sort mem
  fzps --pid-only
  kill "$(fzps --pid-only)"
EOF
}
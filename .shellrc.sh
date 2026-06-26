#!/usr/bin/env bash
# .shellrc.sh
# shared shell entrypoint for:
#   - Windows Git Bash
#   - WSL Ubuntu
#   - Bash
#   - Zsh

# -- directory with files to load --
SHELLRC_DIR="${SHELLRC_DIR:-$HOME/.shellrc.d}"
_SHELLRC_MODULES=(
  ".shell_env.sh"
  ".shell_utils.sh"
  ".shell_aliases.sh"
  ".fzf_tools.sh"
)
SHELL_PLATFORM="unknown"

case "$(uname -s)" in
  Linux)
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
      SHELL_PLATFORM="wsl"
    else
      SHELL_PLATFORM="linux"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    SHELL_PLATFORM="git-bash"
    ;;
  Darwin)
    SHELL_PLATFORM="macos"
    ;;
esac



if [[ -n "${ZSH_VERSION:-}" ]]; then
  SHELL_RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
else
  SHELL_RC_FILE="$HOME/.bashrc"
fi

export SHELLRC_DIR SHELL_PLATFORM SHELL_RC_FILE

for rc_module in "${_SHELLRC_MODULES[@]}"; do
  rc_module="$SHELLRC_DIR/$rc_module"
  [[ -e "$rc_module" ]] || {
    printf '[warn] shellrc file not found: %s\n' "$rc_module" >&2
    continue
  }
  [[ -f "$rc_module" ]] || {
    printf '[warn] shellrc file is not a regular file: %s\n' "$rc_module" >&2
    continue
  }
  [[ -r "$rc_module" ]] || {
    printf '[warn] shellrc file not readable: %s\n' "$rc_module" >&2
    continue
  }
  if ! source "$rc_module"; then
    printf '[error] shellrc failed to source: %s\n' "$rc_module" >&2
    continue
  fi
done
unset rc_module _SHELLRC_MODULES

if [[ "$SHELL_PLATFORM" == "git-bash" ]]; then
  export MSYS2_ARG_CONV_EXCL="${MSYS2_ARG_CONV_EXCL:-}"
  alias explore='explorer .'
  source "$SHELLRC_DIR/.git_bash.sh"
  export PROMPT_COMMAND=set_gitbash_prompt
fi

if [[ "$SHELL_PLATFORM" == "wsl" ]]; then
  export BROWSER="${BROWSER:-wslview}"
  alias explore='explorer.exe .'
fi
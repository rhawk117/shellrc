# shellrc

A cross-platform shell configuration for **Bash**, **Zsh**, **Git Bash**, and **WSL** with:

- shared environment defaults
- practical aliases and Git shortcuts
- utility functions for search/navigation/workflow
- a full suite of `fzf`-powered interactive commands

## Install / Setup Guide

### 1. Requirements

- A POSIX shell (`bash` or `zsh`)
- Python 3 (to run `install.py`)
- Optional tools that unlock extra features: `fzf`, `bat`/`batcat`, `code`, `git`, `less`, `lsof`, `pstree`, `pwdx`

### 2. Clone the repository

```bash
git clone https://github.com/rhawk117/shellrc.git
cd shellrc
```

### 3. Run the installer

```bash
python install.py
```

This copies:

- `.shellrc.sh` to `$HOME/.shellrc.sh`
- `.shellrc.d/` to `$HOME/.shellrc.d/`

It also adds a source block to your active rc file:

- `~/.bashrc` for Bash
- `~/.zshrc` (or `$ZDOTDIR/.zshrc`) for Zsh

### 4. Reload your shell

```bash
source ~/.bashrc
# or
source ~/.zshrc
```

### Installer flags

```bash
python install.py --help
```

Supported options:

- `--backup` create timestamped backups of existing `$HOME/.shellrc.sh` and `$HOME/.shellrc.d`
- `-b, --backup-path <path>` set custom backup location (default: `<repo>/.shellrc.bak.d`)
- `--no-override` exit if destination shellrc files already exist
- `--no-source` skip modifying `.bashrc` / `.zshrc`

### Manual setup (without installer)

Copy the entrypoint and module directory to your home directory, then source `$HOME/.shellrc.sh` from your shell rc file.

```bash
cp .shellrc.sh "$HOME/.shellrc.sh"
cp -r .shellrc.d "$HOME/.shellrc.d"
printf '\n[ -f "$HOME/.shellrc.sh" ] && source "$HOME/.shellrc.sh"\n' >> "$HOME/.bashrc"
```

Use `.zshrc` instead of `.bashrc` when running Zsh.

## Summary (Features + Content Overview)

<details>
<summary><strong>Expand to view what this shellrc provides</strong></summary>

### Core architecture

- **Entrypoint:** `.shellrc.sh`
- **Modules loaded in order:**
  1. `.shell_env.sh`
  2. `.shell_utils.sh`
  3. `.shell_aliases.sh`
  4. `.fzf_tools.sh`
- **Platform detection:** Linux, macOS, Git Bash, WSL
- **Platform extras:**
  - Git Bash: custom prompt, `explore='explorer .'`
  - WSL: `BROWSER=wslview`, `explore='explorer.exe .'`

### Environment defaults (`.shell_env.sh`)

Sets safe defaults for:

- editor/pager (`EDITOR`, `VISUAL`, `PAGER`, `LESS`, `GIT_PAGER`, `MANPAGER`)
- terminal/color (`TERM`, `CLICOLOR`, `CLICOLOR_FORCE`, `GREP_COLORS`)
- history (`HISTSIZE`, `HISTFILESIZE`)
- Python (`PYTHONDONTWRITEBYTECODE`, optional `PYTHONSTARTUP`)
- fuzzy/search tools (`FZF_DEFAULT_OPTS`, `BAT_THEME`, `RIPGREP_CONFIG_PATH`)

### Aliases (`.shell_aliases.sh`)

#### RC helpers

- `catrc` view your active rc file
- `reload` source your active rc file
- `bashrc`, `zshrc` open config files in `${EDITOR:-nano}`

#### Quality-of-life aliases

- directory/navigation: `ls`, `ll`, `la`, `l`, `dir`, `up`, `..`
- file ops: `cp`, `mv`, `rm`, `mkdir`, `rmdir`
- disk/process: `df`, `du`, `psa`, `psg`
- pager/diff/tree/ip colorized aliases when available
- clipboard aliases (`clip`, `copy`) mapped to host-appropriate command

#### bat / batcat aliases (when `bat` or `batcat` is installed)

- `cat` → `bat --paging=never`
- `rawcat` → raw `cat` (bypass bat)
- `ccat` → `bat --style=plain --paging=never` (no decorations)
- `b` → `bat`
- `bn` → `bat --paging=never`
- `bl` → `bat --paging=always`

#### Git aliases

- `gs`, `gstatus`, `gaa`, `gc`, `glog`, `gpull`, `gpush`, `gcommit`, `gdiff`

### Utility functions (`.shell_utils.sh`)

- logging helpers: `rc_debug`, `rc_info`, `rc_success`, `rc_warn`, `rc_error`, `rc_fatal`
- Git workflow:
  - `gitsnap [-m <msg>] [-s|--sync] [-p|--push] [-a|--add <path>]` — add/commit with optional pull and push; `-a` controls what gets staged (default: `.`)
  - `gitfeat -b <new-branch> -r <base-branch>` — create a feature branch synced from a base branch
- navigation/search:
  - `upby <n>` move up multiple directories
  - `rglob [-p <pattern>] [-t <type>]` find by name/type
  - `gr <pattern> [dir]` recursive grep
  - `gri <pattern> [dir]` case-insensitive recursive grep
- bookmarks:
  - `bkmark` (no arg) or `bkmark path|-p` — bookmark current directory
  - `bkmark go|-g` — cd to bookmarked directory
  - `bkmark show|-s` — print bookmarked path

### FZF command suite (`.fzf_tools.sh`)

**`FZ_IGNORE_DIRS`** — space-separated list of directory names pruned from all `fzf` searches (default: `.git node_modules .svn .hg __pycache__` and common build dirs). Override to customise.

- discovery: `fzls`, `fzinfo`, `fzgrep`, `fzg`
- open/edit: `fznano`, `fzless`, `fzmore`, `fzvs`
- navigation: `fzcd`
- Git: `fzgc`
- process explorer: `fzps`
- shell helpers: `fzcomp`, `fzh`, `fzclip`
- compare: `fzdiff`
- docs: `fzhelp`, `fzhelp <command>`

#### Notable options

| Command | Key options |
| --- | --- |
| `fzgrep` / `fzg` | `-i` case-insensitive · `--vs` open match in VS Code · `--hidden` include hidden files · `--no-ignore` disable `FZ_IGNORE_DIRS` |
| `fzps` | `--sort <field>` · `-u <user>` · `--pid-only` print PID · `--cmd-only` print command; interactive: `ctrl-c/m/p/o/u/t/a` to re-sort |
| `fzvs` | `-f/--files` select file instead of directory |
| `fzls` | `-t <type>` · `-a` include hidden · `-l <n>` preview lines |

Most commands include rich preview panes and explicit help via `--help`.

</details>

## Module reference

| File | Purpose |
| --- | --- |
| `.shellrc.sh` | Main entrypoint, platform detection, module loading |
| `.shellrc.d/.shell_env.sh` | Environment variable defaults |
| `.shellrc.d/.shell_aliases.sh` | Aliases (system, shell config, git shortcuts) |
| `.shellrc.d/.shell_utils.sh` | Workflow/logging/search/bookmark helper functions |
| `.shellrc.d/.fzf_tools.sh` | Interactive `fzf` command suite |
| `.shellrc.d/.git_bash.sh` | Git Bash prompt and branch-aware prompt rendering |
| `install.py` | Installer/sync script that copies files + updates rc sourcing |

## Platform behavior

- **Git Bash:** custom two-line prompt with user, host, path, branch, and timestamp
- **WSL:** browser defaults to `wslview`, includes `explore` alias for Windows Explorer
- **Linux/macOS:** shared module set without Git Bash-specific prompt hooks

## Troubleshooting

- If commands are missing, confirm your shell rc file sources `$HOME/.shellrc.sh`.
- If `fz*` commands fail, install `fzf` first.
- If `fzvs` fails, install VS Code CLI (`code`) and ensure it is in `PATH`.
- If color/pager behavior is unexpected, review env overrides in `.shell_env.sh`.

## License

MIT (see `LICENSE`).

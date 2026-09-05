#!/usr/bin/env bash
#
# setup.sh - check and repair the dotfiles setup on this machine.
#
# Safe to run any number of times. Each step reports one of:
#   ok      already correct, nothing done
#   fixed   changed to the expected state
#   skipped a change was needed but you declined (or non-interactive)
#
# Nothing that already exists is overwritten without confirmation, and
# anything replaced is moved to .backups/<timestamp>/ inside the repo first.
#
# Usage: ./setup.sh [--dry-run] [--yes] [--help]

set -euo pipefail

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
DRY_RUN=false
ASSUME_YES=false

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true ;;
    -y|--yes)     ASSUME_YES=true ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_LINK="$HOME/.dotfiles"
BACKUP_ROOT="$DOTFILES_DIR/.backups/$(date +%Y%m%d_%H%M%S)"

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; DIM=''; NC=''
fi

N_OK=0; N_FIXED=0; N_SKIPPED=0; N_WARN=0

ok()      { N_OK=$((N_OK + 1));           printf "${GREEN}  ok${NC}      %s\n" "$1"; }
fixed()   { N_FIXED=$((N_FIXED + 1));     if $DRY_RUN; then printf "${GREEN}  would${NC}   %s\n" "$1"; else printf "${GREEN}  fixed${NC}   %s\n" "$1"; fi; }
skipped() { N_SKIPPED=$((N_SKIPPED + 1)); printf "${YELLOW}  skipped${NC} %s\n" "$1"; }
warn()    { N_WARN=$((N_WARN + 1));       printf "${YELLOW}  warn${NC}    %s\n" "$1"; }
info()    {                               printf "${DIM}          %s${NC}\n" "$1"; }
fail()    {                               printf "${RED}  error${NC}   %s\n" "$1" >&2; exit 1; }
section() {                               printf "\n${BLUE}%s${NC}\n" "$1"; }

# Print a path with $HOME shortened to ~
short() {
  case "$1" in
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    "$HOME")   printf '~' ;;
    *)         printf '%s' "$1" ;;
  esac
}

# -----------------------------------------------------------------------------
# Prompting
# -----------------------------------------------------------------------------
# confirm "question"  -> 0 if the user agrees, 1 otherwise.
# --yes answers yes to everything; --dry-run answers yes so the "would ..."
# messages show the full plan; EOF on stdin answers no.
confirm() {
  if $ASSUME_YES || $DRY_RUN; then
    return 0
  fi
  local reply
  printf "${YELLOW}  ?${NC}       %s [y/N] " "$1"
  if read -r reply; then
    [ -t 0 ] || echo ""
  else
    # EOF on stdin (not interactive): treat as "no".
    reply=""
    echo ""
    info "no input available; answering no (use --yes to assume yes)"
  fi
  case "$reply" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Filesystem helpers (all honour --dry-run)
# -----------------------------------------------------------------------------
# Canonical absolute path of an existing file or directory.
canon() {
  if [ -d "$1" ]; then
    (cd "$1" && pwd -P)
  else
    (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")")
  fi
}

# Absolute target of a symlink, unresolved (relative targets made absolute).
link_target() {
  local target
  target="$(readlink "$1")"
  target="${target%/}"
  case "$target" in
    /*) printf '%s\n' "$target" ;;
    *)  printf '%s/%s\n' "$(dirname "$1")" "$target" ;;
  esac
}

# 0 if $1 is a symlink whose target resolves to the same place as $2.
link_points_to() {
  [ -L "$1" ] || return 1
  local target
  target="$(link_target "$1")"
  [ -e "$target" ] || return 1
  [ "$(canon "$target")" = "$(canon "$2")" ]
}

# Move $1 into the backup directory, preserving its path relative to $HOME.
backup() {
  local rel dest
  case "$1" in
    "$HOME"/*) rel="${1#"$HOME"/}" ;;
    *)         rel="$(basename "$1")" ;;
  esac
  dest="$BACKUP_ROOT/$rel"
  if $DRY_RUN; then
    info "would move $(short "$1") -> $(short "$dest")"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  mv "$1" "$dest"
  info "moved $(short "$1") -> $(short "$dest")"
}

# Remove a symlink (never follows it).
remove_link() {
  $DRY_RUN && return 0
  rm "$1"
}

make_link() {
  $DRY_RUN && return 0
  mkdir -p "$(dirname "$2")"
  ln -s "$1" "$2"
}

append_file() {
  $DRY_RUN && return 0
  mkdir -p "$(dirname "$2")"
  # Ensure the existing file ends with a newline before appending.
  if [ -s "$2" ] && [ "$(tail -c 1 "$2" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$2"
  fi
  cat "$1" >> "$2"
}

# ensure_link SOURCE LINK LABEL
# Make LINK a symlink to SOURCE. Anything else at LINK is only replaced after
# confirmation; real files/dirs are backed up first.
ensure_link() {
  local source="$1" link="$2" label="$3"

  if link_points_to "$link" "$source"; then
    ok "$label -> $(short "$source")"
    return 0
  fi

  if [ -L "$link" ]; then
    local current
    current="$(link_target "$link")"
    if [ -e "$current" ]; then
      if ! confirm "$label is a symlink to $(short "$current"). Repoint it to $(short "$source")?"; then
        skipped "$label left pointing at $(short "$current")"
        return 0
      fi
    else
      # Dangling symlink: nothing is lost by replacing it, but still ask.
      if ! confirm "$label is a broken symlink (-> $(short "$current")). Replace it?"; then
        skipped "$label left as broken symlink"
        return 0
      fi
    fi
    remove_link "$link"
    make_link "$source" "$link"
    fixed "$label -> $(short "$source")"
    return 0
  fi

  if [ -e "$link" ]; then
    local kind="file"
    [ -d "$link" ] && kind="directory"
    if ! confirm "$label is an existing $kind. Back it up and replace with a symlink?"; then
      skipped "$label left as existing $kind"
      return 0
    fi
    backup "$link"
    make_link "$source" "$link"
    fixed "$label -> $(short "$source") (original backed up)"
    return 0
  fi

  make_link "$source" "$link"
  fixed "$label -> $(short "$source")"
}

# -----------------------------------------------------------------------------
# Step 1: ~/.dotfiles -> repo
# -----------------------------------------------------------------------------
setup_repo_link() {
  section "Repository link"
  ensure_link "$DOTFILES_DIR" "$DOTFILES_LINK" "~/.dotfiles"
}

# -----------------------------------------------------------------------------
# Step 2: shell rc files source the repo configs
# -----------------------------------------------------------------------------
# ensure_rc SNIPPET RC CONFIG
# RC must contain a line sourcing CONFIG (the snippet provides it). If the rc
# file is missing it is created; if it exists without the line, the snippet is
# appended after confirmation. Never appends twice.
ensure_rc() {
  local snippet="$1" rc="$2" config="$3"
  local label
  label="$(short "$rc")"
  [ -f "$snippet" ] || fail "missing snippet in repo: $snippet"

  # Match `source ~/.dotfiles/dotfiles/.zshrc` or `. ~/.dotfiles/...`, with ~ or $HOME.
  local pattern='^[[:space:]]*(source|\.)[[:space:]]+("?~|"?\$HOME|'"$HOME"')/\.dotfiles/dotfiles/'"$(basename "$config")"'"?([[:space:]]|$)'

  if [ -f "$rc" ]; then
    local count
    count="$(grep -cE "$pattern" "$rc" || true)"
    if [ "$count" -eq 1 ]; then
      ok "$label sources $(short "$config")"
      return 0
    elif [ "$count" -gt 1 ]; then
      warn "$label sources $(short "$config") $count times; remove the duplicates by hand"
      return 0
    fi
    if grep -q "NateHadz" "$rc"; then
      warn "$label has the NateHadz header but no source line; the snippet was probably edited"
    fi
    if ! confirm "$label exists but does not source $(short "$config"). Append the snippet?"; then
      skipped "$label not modified"
      return 0
    fi
    append_file "$snippet" "$rc"
    fixed "$label now sources $(short "$config") (snippet appended)"
    return 0
  fi

  if [ -e "$rc" ]; then
    warn "$label exists but is not a regular file; not touching it"
    return 0
  fi

  append_file "$snippet" "$rc"
  fixed "$label created from $(short "$snippet")"
}

setup_shell_rc() {
  section "Shell configuration"
  ensure_rc "$DOTFILES_DIR/dotfiles/.zshrc.local"  "$HOME/.zshrc"  "$DOTFILES_DIR/dotfiles/.zshrc"
  ensure_rc "$DOTFILES_DIR/dotfiles/.bashrc.local" "$HOME/.bashrc" "$DOTFILES_DIR/dotfiles/.bashrc"

  # macOS login shells read ~/.bash_profile, not ~/.bashrc.
  if [ "$(uname -s)" = "Darwin" ]; then
    if [ ! -f "$HOME/.bash_profile" ] || ! grep -qE '\.bashrc' "$HOME/.bash_profile"; then
      warn "~/.bash_profile does not source ~/.bashrc; bash login shells will not load the config"
      info 'add to ~/.bash_profile:  [ -f ~/.bashrc ] && source ~/.bashrc'
    fi
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
echo ""
echo "Dotfiles setup"
echo "  repo:  $DOTFILES_DIR"
echo "  home:  $HOME"
$DRY_RUN && echo "  mode:  dry run (no changes will be made)"

setup_repo_link
setup_shell_rc

section "Summary"
if $DRY_RUN; then
  printf "  %d ok, %d to fix, %d skipped, %d warnings\n" "$N_OK" "$N_FIXED" "$N_SKIPPED" "$N_WARN"
else
  printf "  %d ok, %d fixed, %d skipped, %d warnings\n" "$N_OK" "$N_FIXED" "$N_SKIPPED" "$N_WARN"
fi
if $DRY_RUN; then
  if [ "$N_FIXED" -gt 0 ]; then
    info "run without --dry-run to apply"
  fi
elif [ "$N_FIXED" -gt 0 ]; then
  [ -d "$BACKUP_ROOT" ] && info "backups in $(short "$BACKUP_ROOT")"
  info "reload your shell:  source ~/.zshrc"
fi
echo ""

#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Dotfiles Setup Script
# =============================================================================
#
# This script creates symlinks from your home directory to the dotfiles
# in this repository. It safely backs up existing files before creating links.
#
# Usage: ./setup.sh [--force]
#   --force: Skip confirmation prompts
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path to the dotfiles directory (where this script lives)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$DOTFILES_DIR/.backups/$(date +%Y%m%d_%H%M%S)"
FORCE=false
BACKUP_NEEDED=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --force)
      FORCE=true
      shift
      ;;
  esac
done

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
  echo -e "\n${BLUE}==>${NC} $1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}!${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

confirm() {
  if [ "$FORCE" = true ]; then
    return 0
  fi

  local prompt="$1"
  local response
  read -rp "$(echo -e "${YELLOW}?${NC} $prompt (y/N): ")" response
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_for_existing_files() {
  local files_to_check=(
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.config/mise/config.toml"
    "$HOME/.config/mise/settings.toml"
  )

  # Add individual skills to backup check
  for skill_dir in "$DOTFILES_DIR/skills"/*/ ; do
    if [ -d "$skill_dir" ]; then
      skill_name=$(basename "$skill_dir")
      if [ -f "$skill_dir/SKILL.md" ]; then
        files_to_check+=("$HOME/.claude/skills/$skill_name")
      fi
    fi
  done

  local existing_files=()
  for file in "${files_to_check[@]}"; do
    if [ -e "$file" ] && [ ! -L "$file" ]; then
      existing_files+=("$file")
    fi
  done

  if [ ${#existing_files[@]} -gt 0 ]; then
    echo ""
    print_warning "Found existing configuration files:"
    for file in "${existing_files[@]}"; do
      echo "  - $file"
    done
    echo ""

    if confirm "Would you like to back up these files before replacing them?"; then
      BACKUP_NEEDED=true
      return 0
    else
      print_warning "Skipping backup. Existing files will be replaced."
      return 1
    fi
  fi

  return 1
}

backup_file() {
  local file=$1
  if [ "$BACKUP_NEEDED" = true ] && [ -e "$file" ] && [ ! -L "$file" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -r "$file" "$BACKUP_DIR/"
    print_success "Backed up: $file -> $BACKUP_DIR/"
    return 0
  fi
  return 1
}

create_symlink() {
  local source=$1
  local target=$2

  # Check if source exists
  if [ ! -e "$source" ]; then
    print_error "Source file does not exist: $source"
    return 1
  fi

  # If target exists and is not a symlink, back it up
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    backup_file "$target"
    rm -rf "$target"
  elif [ -L "$target" ]; then
    # If it's already a symlink, remove it
    rm "$target"
  fi

  # Create the symlink
  ln -s "$source" "$target"
  print_success "Linked: $target -> $source"
}

# =============================================================================
# Main Setup
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║       Dotfiles Setup Script                ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "Dotfiles directory: $DOTFILES_DIR"
echo ""

if ! confirm "This will symlink dotfiles to your home directory. Continue?"; then
  echo "Setup cancelled."
  exit 0
fi

# Check for existing files and ask about backup
check_for_existing_files || true

# =============================================================================
# Create necessary directories
# =============================================================================

print_header "Creating necessary directories"

mkdir -p "$HOME/.config/mise"
print_success "Created ~/.config/mise"

mkdir -p "$HOME/.claude"
print_success "Created ~/.claude"

# =============================================================================
# Shell Configuration Files
# =============================================================================

print_header "Setting up shell configuration"

create_symlink "$DOTFILES_DIR/shell/zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/shell/bashrc" "$HOME/.bashrc"
create_symlink "$DOTFILES_DIR/shell/bash_profile" "$HOME/.bash_profile"

# Create .zshrc.local if it doesn't exist
if [ ! -f "$HOME/.zshrc.local" ]; then
  print_warning "Creating ~/.zshrc.local from example template"
  cp "$DOTFILES_DIR/shell/zshrc.local.example" "$HOME/.zshrc.local"
  print_success "Created ~/.zshrc.local (customize this for machine-specific config)"
else
  print_success "~/.zshrc.local already exists (not overwriting)"
fi

# =============================================================================
# Mise Configuration
# =============================================================================

print_header "Setting up mise configuration"

create_symlink "$DOTFILES_DIR/mise/config.toml" "$HOME/.config/mise/config.toml"
create_symlink "$DOTFILES_DIR/mise/settings.toml" "$HOME/.config/mise/settings.toml"

# =============================================================================
# Claude Code Skills
# =============================================================================

print_header "Setting up Claude Code skills"

# Create skills directory if it doesn't exist
mkdir -p "$HOME/.claude/skills"

# Function to check if skill is enabled in config
is_skill_enabled() {
  local skill_name=$1
  local config_file="$DOTFILES_DIR/skills/config.toml"
  local local_config="$DOTFILES_DIR/skills/config.local.toml"

  # Check local config first (machine-specific overrides)
  if [ -f "$local_config" ]; then
    if grep -q "^\[$skill_name\]" "$local_config"; then
      if grep -A 1 "^\[$skill_name\]" "$local_config" | grep -q "enabled = true"; then
        return 0
      else
        return 1
      fi
    fi
  fi

  # Fall back to main config
  if [ -f "$config_file" ]; then
    if grep -A 1 "^\[$skill_name\]" "$config_file" | grep -q "enabled = true"; then
      return 0
    else
      return 1
    fi
  fi

  # If no config exists, enable all skills by default
  return 0
}

# Symlink individual skills from the dotfiles repo
for skill_dir in "$DOTFILES_DIR/skills"/*/ ; do
  if [ -d "$skill_dir" ]; then
    skill_name=$(basename "$skill_dir")
    # Only process directories with a valid SKILL.md file
    if [ -f "$skill_dir/SKILL.md" ]; then
      if is_skill_enabled "$skill_name"; then
        create_symlink "$skill_dir" "$HOME/.claude/skills/$skill_name"
      else
        # Remove symlink if skill is disabled
        if [ -L "$HOME/.claude/skills/$skill_name" ]; then
          rm "$HOME/.claude/skills/$skill_name"
          print_warning "Removed disabled skill: $skill_name"
        fi
      fi
    fi
  fi
done

# =============================================================================
# PATH Setup
# =============================================================================

print_header "Configuring PATH"

# Check if bin directory is already in PATH (via symlinked configs)
if [[ ":$PATH:" == *":$DOTFILES_DIR/bin:"* ]]; then
  print_success "bin directory already in PATH"
else
  print_warning "bin directory will be added to PATH when you restart your shell"
fi

# Update the dotfiles symlink for easy access
if [ ! -L "$HOME/.dotfiles" ]; then
  ln -s "$DOTFILES_DIR" "$HOME/.dotfiles"
  print_success "Created ~/.dotfiles symlink to $DOTFILES_DIR"
else
  print_success "~/.dotfiles symlink already exists"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
print_header "Setup Complete!"
echo ""

if [ -d "$BACKUP_DIR" ]; then
  echo "Original files backed up to:"
  echo "  $BACKUP_DIR"
  echo ""
fi

echo "Next steps:"
echo "  1. Review and customize ~/.zshrc.local for machine-specific settings"
echo "  2. Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"
echo "  3. Verify PATH includes $DOTFILES_DIR/bin"
echo "  4. Configure mise tools in ~/.config/mise/config.toml"
echo ""
print_success "All done! Enjoy your dotfiles."
echo ""

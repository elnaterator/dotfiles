#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the absolute path to the dotfiles directory (where this script lives)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}!${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

check_for_existing_files() {
  err=0
  if [ -e "$HOME/.dotfiles" ]; then
    print_warning "~/.dotfiles already exists. Exiting without changes."
    err=1
  fi

  if [ -f "$HOME/.zshrc" ] && grep -q "NateHadz" "$HOME/.zshrc"; then
    print_warning "~/.zshrc already contains NateHadz. Exiting without changes."
    err=1
  fi

  if [ -f "$HOME/.bashrc" ] && grep -q "NateHadz" "$HOME/.bashrc"; then
    print_warning "~/.bashrc already contains NateHadz. Exiting without changes."
    err=1
  fi

  if [ $err -ne 0 ]; then
    exit 1
  fi
}

append_file_contents() {
  local source=$1
  local target=$2

  if [ ! -f "$source" ]; then
    print_error "Source file does not exist: $source"
    exit 1
  fi

  touch "$target"
  cat "$source" >> "$target"
  print_success "Appended $source to $target"
}

echo ""
echo "Dotfiles setup"
echo "Dotfiles directory: $DOTFILES_DIR"
echo ""

check_for_existing_files

ln -s "$DOTFILES_DIR" "$HOME/.dotfiles"
print_success "Created ~/.dotfiles symlink to $DOTFILES_DIR"

append_file_contents "$HOME/.dotfiles/dotfiles/.zshrc.local" "$HOME/.zshrc"
append_file_contents "$HOME/.dotfiles/dotfiles/.bashrc.local" "$HOME/.bashrc"

echo ""
print_success "Setup complete."
echo ""

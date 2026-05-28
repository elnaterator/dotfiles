#!/bin/zsh

# =============================================================================
# ZSH Configuration
# =============================================================================

# Prevent double-loading in VSCode (shell integration causes re-source)
if [[ -n "$_ZSHRC_LOADED" ]]; then
  return
fi
export _ZSHRC_LOADED=1

# =============================================================================
# Human vs AI Agent Detection
# =============================================================================
# If it is an actual human using the terminal then load human settings
# Skip human settings if AI agent environment variables are detected
# Kiro terminals are detected by: TERM_PROGRAM=kiro AND Q_TERM_DISABLED=1
# VSCode GitHub Copilot terminals: TERM_PROGRAM=vscode AND VSCODE_PREVENT_SHELL_HISTORY=1
if [[ "$TERM_PROGRAM" == "kiro" && "$Q_TERM_DISABLED" == "1" ]] || \
   [[ "$TERM_PROGRAM" == "vscode" && "$VSCODE_PREVENT_SHELL_HISTORY" == "1" ]]; then
  # This is an AI agent terminal - skip human settings
  :
else
  # This appears to be a human terminal session
  [ -f ~/.dotfiles/dotfiles/.zshrc.human ] && source ~/.dotfiles/dotfiles/.zshrc.human
fi


# =============================================================================
# PATH Configuration
# =============================================================================
# Add dotfiles bin directory to PATH
export PATH="$HOME/.dotfiles/bin:$PATH"

# Standard paths
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Add docker bin if it exists (user install rather than system-wide)
if [ -d "$HOME/.docker/bin" ]; then
  export PATH="$HOME/.docker/bin:$PATH"
fi

# =============================================================================
# History Configuration
# =============================================================================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY           # Append to history file
setopt SHARE_HISTORY            # Share history between sessions
setopt HIST_IGNORE_DUPS         # Ignore duplicate commands
setopt HIST_IGNORE_SPACE        # Ignore commands starting with space
setopt HIST_REDUCE_BLANKS       # Remove unnecessary blanks

# =============================================================================
# Completion
# =============================================================================
# Docker CLI completions
fpath=(~/.docker/completions $fpath)

autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# =============================================================================
# Aliases
# =============================================================================
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# Other aliases
alias claudep="claude --dangerously-skip-permissions"

# =============================================================================
# Environment Variables
# =============================================================================
export EDITOR=vim
export VISUAL=vim

# Disable pager for AWS CLI by default (can be overridden in .zshrc.local)
export AWS_PAGER=""

# =============================================================================
# Mise (mise-en-place) - Development tool version manager
# =============================================================================
# Use shims instead of dynamic activate for compatibility with AI coding assistants
# This is more reliable for non-interactive shells like those used by Claude Code
if [ -d "$HOME/.local/share/mise/shims" ]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

# =============================================================================
# Load homebrew tools into PATH
# =============================================================================
if command -v brew >/dev/null 2>&1; then
  # Add openssl to PATH
  openssl_prefix="$(brew --prefix openssl@3 2>/dev/null || brew --prefix openssl 2>/dev/null || true)"
  if [[ -n "$openssl_prefix" && -d "$openssl_prefix/bin" ]]; then
    export PATH="$openssl_prefix/bin:$PATH"
  fi
fi

# =============================================================================
# Custom functions
# =============================================================================
# Usage: schedule "5pm" "command to run"
schedule() {
    echo "cd $(pwd) && $2" | at $1
    echo "Scheduled: '$2' at $1"
}

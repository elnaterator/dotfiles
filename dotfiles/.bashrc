# =============================================================================
# Bash Configuration
# =============================================================================

# Add dotfiles bin directory to PATH
export PATH="$HOME/.dotfiles/bin:$PATH"

# =============================================================================
# History Configuration
# =============================================================================
HISTFILE=~/.bash_history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:ignorespace  # Ignore duplicates and commands starting with space
shopt -s histappend                 # Append to history file

# =============================================================================
# Shell Options
# =============================================================================
shopt -s checkwinsize  # Update LINES and COLUMNS after each command

# =============================================================================
# Prompt
# =============================================================================
# Simple prompt with current directory
PS1='\[\033[01;34m\]\w\[\033[00m\] \[\033[01;32m\]❯\[\033[00m\] '

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

# =============================================================================
# Environment Variables
# =============================================================================
export EDITOR=vim
export VISUAL=vim

# Disable pager for AWS CLI by default
export AWS_PAGER=""

# =============================================================================
# Mise (mise-en-place) - Development tool version manager
# =============================================================================
if command -v mise &> /dev/null; then
  eval "$(mise activate bash)"
fi

# =============================================================================
# Load machine-specific configuration
# =============================================================================
[ -f ~/.bashrc.local ] && source ~/.bashrc.local

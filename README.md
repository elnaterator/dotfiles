# Dotfiles

Personal dotfiles repository with shell configurations, utility scripts, and development tool settings.

## Quick Start

Clone this repository and run the setup script:

```bash
git clone <your-repo-url> ~/workspace/dotfiles
cd ~/workspace/dotfiles
./setup.sh
```

The setup script will:
- Create symlinks from your home directory to configuration files in this repo
- Back up any existing configuration files to `~/.dotfiles_backup/`
- Set up necessary directories (like `~/.config/mise/`)
- Create a `~/.zshrc.local` template for machine-specific customizations
- Add the `bin/` directory to your PATH

## Repository Structure

```
dotfiles/
├── bin/              # Utility scripts (AWS tools, vault, git helpers)
├── shell/            # Shell configuration files
│   ├── zshrc         # Main zsh configuration
│   ├── bashrc        # Main bash configuration
│   └── bash_profile  # Bash profile
├── mise/             # mise-en-place (development tool version manager)
│   ├── config.toml   # Global mise configuration
│   └── settings.toml # mise settings
├── skills/           # AI Agent Skills
├── agents/           # AI Agents
├── setup.sh          # Main setup script
└── README.md         # This file
```

## Configuration Files

### Shell (zsh/bash)

Shell configurations are in the `shell/` directory and will be symlinked to:
- `~/.zshrc` → `shell/zshrc`
- `~/.bashrc` → `shell/bashrc`
- `~/.bash_profile` → `shell/bash_profile`

**Machine-Specific Customizations:**

For machine-specific settings (work aliases, credentials, paths), use `~/.zshrc.local`:

```bash
# Edit your local config
vim ~/.zshrc.local
```

This file is gitignored and won't be committed. Use it for:
- Work-specific aliases and functions
- Machine-specific PATH additions
- API keys and credentials
- Environment variable overrides

### Mise

Mise configurations are in the `mise/` directory and will be symlinked to `~/.config/mise/`.

Edit `mise/config.toml` to:
- Set global tool versions (node, python, go, etc.)
- Configure environment variables
- Set up tool aliases

### Utility Scripts

All scripts in `bin/` will be available in your PATH after setup. Key utilities:

- **vault** - RSA-encrypted password manager
- **assume-role** - AWS STS role assumption helper
- **ec2s** - Filter EC2 instances by tag
- **subnet-ips** - Analyze AWS subnet IP usage
- **kms-keys** - List KMS keys with aliases
- **git-summary** - Show recent git commits in a formatted table
- **mutate** - Text mutation utility
- **ansi_colors** - ANSI color reference

See `bin/` directory for full list. Most scripts include usage information when run without arguments.

## Manual Setup

If you prefer not to use the automated setup script:

1. Symlink shell configs:
   ```bash
   ln -s ~/.dotfiles/shell/zshrc ~/.zshrc
   ln -s ~/.dotfiles/shell/bashrc ~/.bashrc
   ln -s ~/.dotfiles/shell/bash_profile ~/.bash_profile
   ```

2. Symlink mise configs:
   ```bash
   mkdir -p ~/.config/mise
   ln -s ~/.dotfiles/mise/config.toml ~/.config/mise/config.toml
   ln -s ~/.dotfiles/mise/settings.toml ~/.config/mise/settings.toml
   ```

3. Add bin to PATH (add to your shell config):
   ```bash
   export PATH="$HOME/.dotfiles/bin:$PATH"
   ```

4. Create local config:
   ```bash
   cp ~/.dotfiles/shell/zshrc.local.example ~/.zshrc.local
   ```

## Updating

To update your dotfiles:

```bash
cd ~/.dotfiles
git pull
```

Since configuration files are symlinked, changes are automatically reflected.

## Customization

### Adding New Scripts

1. Add executable script to `bin/`
2. Make it executable: `chmod +x bin/script-name`
3. Commit and push

### Adding New Configs

1. Add config file to appropriate directory (shell/, mise/, etc.)
2. Update `setup.sh` to create the symlink
3. Document in this README

### Skills Directory

The `skills/` directory is for AI Agent Skills. See [skills/README.md](skills/README.md) for details.

Skills are reusable, specialized capabilities that can be invoked by AI agents to perform specific tasks.

### Agents Directory

The `agents/` directory is for AI Agents. See [agents/README.md](agents/README.md) for details.

Agents are autonomous AI systems that can perform complex, multi-step tasks and maintain context across workflows.

Both skills and agents:
- Are symlinked to `~/.claude/skills/` and `~/.claude/agents/` respectively
- Can be enabled/disabled via `config.toml` in their respective directories
- Support machine-specific overrides via `config.local.toml` (gitignored)

## Dependencies

Common tools used by scripts:
- **aws** CLI (for AWS scripts)
- **jq** (JSON processing)
- **openssl** 1.0.0+ (for vault script)
- **mise** (optional, for development tool management)

## Legacy Setup Script

The old `setup-path.sh` script is deprecated in favor of the new `setup.sh` script. If you previously used `setup-path.sh`, you can safely remove the PATH export it added to your shell profile, as the new symlinked configs handle this automatically.

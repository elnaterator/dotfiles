# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing:
- Shell configurations (zsh, bash) with machine-specific customization support
- Development tool configurations (mise)
- Utility scripts for AWS operations, security, git workflows, and productivity
- AI Agent Skills directory

The repository uses a symlink-based approach where configuration files in the repo are linked to their expected locations in the home directory.

## Setup

**Initial setup:**
```bash
./setup.sh
```

The setup script:
- Creates symlinks from `~/.zshrc`, `~/.bashrc`, etc. to files in this repo
- Backs up existing configs to `~/.dotfiles_backup/[timestamp]/`
- Creates `~/.zshrc.local` from template for machine-specific settings
- Sets up mise configuration in `~/.config/mise/`
- Creates `~/.dotfiles` symlink to repository location

**Running the setup script is idempotent** - safe to run multiple times.

## Repository Structure

```
dotfiles/
├── bin/              # Utility scripts (executable, no extensions)
├── shell/            # Shell configurations
│   ├── zshrc         # Main zsh config (→ ~/.zshrc)
│   ├── bashrc        # Main bash config (→ ~/.bashrc)
│   ├── bash_profile  # Bash profile (→ ~/.bash_profile)
│   └── zshrc.local.example  # Template for machine-specific config
├── mise/             # mise-en-place configurations
│   ├── config.toml   # Global mise config (→ ~/.config/mise/config.toml)
│   └── settings.toml # mise settings (→ ~/.config/mise/settings.toml)
├── skills/           # AI Agent Skills
├── setup.sh          # Main setup script
└── setup-path.sh     # Legacy PATH setup (deprecated)
```

## Architecture

### Symlink Strategy

Configuration files are symlinked rather than copied:
- **Benefit**: Changes to files in repo are immediately active
- **Workflow**: Edit `shell/zshrc` → changes apply to `~/.zshrc` automatically
- **Safety**: Setup script backs up existing files before creating symlinks

### Machine-Specific Customization Pattern

The shell configs use a `.local` file pattern for machine-specific settings:

**How it works:**
1. Main config (`shell/zshrc`) is tracked in git and symlinked to `~/.zshrc`
2. At the end, it sources `~/.zshrc.local` if it exists
3. `~/.zshrc.local` is gitignored and stays on each machine
4. Use `~/.zshrc.local` for work-specific paths, aliases, credentials, etc.

**Template:** `shell/zshrc.local.example` provides a starting point

This allows:
- Shared configuration across all machines (tracked in git)
- Machine-specific overrides without conflicts
- Work/personal separation without separate configs

### Script Organization

All executable scripts are located in `bin/` with no file extensions. Scripts are implemented in bash or Python 3, depending on complexity:
- Simple AWS/shell operations: bash
- Text manipulation/algorithms: Python 3

**PATH setup:** Shell configs add `$HOME/.dotfiles/bin` to PATH automatically.

### AWS Scripts Pattern

AWS scripts follow a consistent pattern:
- Set `export AWS_PAGER=""` to disable pagination
- Use `aws` CLI with `--query` for JSON manipulation
- Use `jq` for complex JSON processing
- Output results as tables using `--output table` or `column -t`

### Credential Management Pattern

Scripts that handle AWS credentials (e.g., `assume-role`) follow this pattern:
- Backup existing credentials by renaming `[default]` to `[default-bak]`
- Store temporary credentials in `~/.aws/credentials`
- Provide `revert` command to restore original credentials
- Maintain history files in `~/.aws/` for convenience

## Key Scripts

### vault
RSA-encrypted password manager using OpenSSL. Architecture:
- Master passphrase protects 4096-bit RSA private key at `~/.vault/id_rsa_vault`
- Secrets encrypted with public key, stored in `~/.vault/secrets/`
- Requires OpenSSL 1.0.0+ with `genpkey` and `pkeyutl` support (not LibreSSL)
- Interactive menu system using bash `select`

### assume-role
AWS STS role assumption helper. Workflow:
1. Validates role ARN format
2. Calls `aws sts assume-role` with timestamped session name
3. Uses `jq` to extract credentials from JSON response
4. Updates `~/.aws/credentials` with temporary credentials
5. Maintains role history in `~/.aws/role-history`

Special commands: `revert`, `show`, `open`, `config`

### subnet-ips
AWS subnet IP usage analyzer. Process:
1. Accepts subnet name or ID
2. Looks up CIDR block
3. Calculates total IPs from CIDR using lookup table
4. Queries network interfaces via `aws ec2 describe-network-interfaces`
5. Outputs sorted list of used private IPs

### ec2s
Simple EC2 instance filter by `tag:Name`. Uses AWS CLI `--query` to format output as table with Name, IPs, Type, ID, and State.

### kms-keys
Lists AWS KMS keys with aliases. Combines `aws kms list-aliases` and `aws kms list-keys` using `jq` join operation on KeyId.

### git-summary
Displays recent git commits in formatted table. Defaults to last 48 hours, accepts custom hour parameter.

### mutate
Python utility that replaces alphanumeric characters with random alternatives while preserving non-alphanumeric characters. Accepts string (`-s`) or file (`-f`) input.

### ansi_colors
Reference utility displaying all ANSI color codes and text styles (foreground, background, RGB, 256-color palette).

## Development Guidelines

### Testing Changes

**Shell configs:**
```bash
# Edit config
vim shell/zshrc

# Test immediately (config is symlinked)
source ~/.zshrc

# Or restart terminal
```

**Scripts:**
```bash
# Run script directly from bin/
./bin/script-name [args]

# Or if PATH is set up
script-name [args]
```

**Setup script:**
```bash
# Test setup in dry-run mode would require adding --dry-run flag
# For now, test in a VM or backup your configs first
./setup.sh
```

### Adding New Configuration Files

1. Add config file to appropriate directory (shell/, mise/, etc.)
2. Update `setup.sh` to create the symlink in the appropriate section
3. Test by running `./setup.sh` (it's idempotent)
4. Document in README.md
5. Commit both the config file and updated setup.sh

Example:
```bash
# Add new config
echo "config content" > shell/new-config

# Update setup.sh to add symlink
vim setup.sh  # Add create_symlink line

# Test
./setup.sh

# Commit
git add shell/new-config setup.sh README.md
git commit -m "Add new-config for X"
```

### Adding New Scripts

1. Add executable script to `bin/` with no file extension
2. Make it executable: `chmod +x bin/script-name`
3. Test: `./bin/script-name [args]`
4. Document purpose in README.md if it's a commonly-used script
5. Commit

### AWS Scripts

When modifying AWS scripts:
- Test with appropriate AWS credentials configured
- Verify `--query` syntax returns expected JSON structure
- Ensure `jq` filters handle edge cases (empty results, missing fields)
- Always set `AWS_PAGER=""` for non-interactive use

### Error Handling

Follow existing patterns:
- Check command exit codes: `if [ $? -ne 0 ]; then`
- Use `set -euo pipefail` for strict error handling (when appropriate)
- Provide clear error messages to stderr: `echo "Error: ..." >&2`
- Clean up temporary files on error
- For sensitive data (passphrases), use `unset` after use

### Machine-Specific Settings

**Never commit:**
- Credentials or API keys
- Machine-specific paths or hostnames
- Work-specific configuration

**Instead:**
- Add examples to `shell/zshrc.local.example`
- Document in comments what should go in `.local` files
- Use environment variable placeholders

### Skills Directory

The `skills/` directory is for AI Agent Skills. See `skills/README.md` for structure and guidelines.

**Configuration:**
- `skills/config.toml`: Main config for enabling/disabling repo skills
- `skills/config.local.toml`: Machine-specific overrides (gitignored)

**External Skills:**
To include skills from outside this repo, add paths to `skills/config.local.toml`:

```toml
[external_skills]
paths = [
  "~/projects/my-custom-skills/work-helper",
  "/opt/shared-skills/deploy-assistant",
]
```

The setup script will symlink external skills to `~/.claude/skills/` alongside repo skills. External skills must have a `SKILL.md` file to be recognized.

### Agents Directory

The `agents/` directory contains Claude Code subagents. See `agents/README.md` for structure and guidelines.

**Configuration:**
- `agents/config.toml`: Main config for enabling/disabling repo agents
- `agents/config.local.toml`: Machine-specific overrides (gitignored)

**External Agents:**
To include agents from outside this repo, add paths to `agents/config.local.toml`:

```toml
[external_agents]
paths = [
  "~/projects/my-custom-agents/deployment-expert.md",
  "/opt/shared-agents/security-auditor.md",
]
```

The setup script will symlink external agents to `~/.claude/agents/` alongside repo agents. External agents must be `.md` files.

## Dependencies

Common dependencies assumed to be available:
- `bash` or `zsh` (shell)
- `aws` CLI (AWS scripts)
- `jq` (JSON processing)
- `openssl` 1.0.0+ with genpkey/pkeyutl (vault)
- `column` (table formatting)
- `mise` (optional, for development tool management)
- Python 3 (mutate script)

## Legacy Files

- **setup-path.sh**: Deprecated in favor of `setup.sh`. Old script only handled PATH setup; new script handles all symlinks and configuration.

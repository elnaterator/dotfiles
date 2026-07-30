# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing:
- Shell configurations (zsh, bash) with machine-specific customization support
- Utility scripts for AWS operations, security, git workflows, and productivity
- AI Agent Skills and Agents directories

The repository uses a symlink-based approach where configuration files in the repo are linked to their expected locations in the home directory.

## Setup

**Initial setup:**
```bash
./setup.sh
```

The setup script does exactly two things:
- Creates a `~/.dotfiles` symlink pointing at the repository
- Appends `dotfiles/.zshrc.local` to `~/.zshrc` and `dotfiles/.bashrc.local` to `~/.bashrc`

Those appended snippets each `source` the real config in `dotfiles/` (`.zshrc` / `.bashrc`),
which is what adds `bin/` to PATH and loads everything else.

**It does NOT** symlink shell configs directly, create `.backups/`, generate `~/.zshrc.local`
from a template, or install skills/agents. Those are either handled by the sourced configs or
done manually (see below).

**setup.sh is not idempotent** - it appends unconditionally and exits early only if `~/.dotfiles`
already exists or the rc files already contain `NateHadz`. Re-running after a partial setup can
duplicate lines.

## Repository Structure

```
dotfiles/
├── bin/              # Utility scripts (executable, no extensions)
├── dotfiles/         # Shell configurations
│   ├── .zshrc        # Main zsh config (sourced by ~/.zshrc)
│   ├── .bashrc       # Main bash config (sourced by ~/.bashrc)
│   ├── .zshrc.local  # Snippet appended to ~/.zshrc; sources .zshrc + machine-specific settings
│   └── .bashrc.local # Snippet appended to ~/.bashrc; sources .bashrc
├── skills/           # AI Agent Skills
├── agents/           # AI Agents
├── setup.sh          # Main setup script
└── setup-path.sh     # Legacy PATH setup (deprecated)
```

## Architecture

### Symlink + Source Strategy

The repo itself is symlinked to `~/.dotfiles`, and the real rc files `source` configs out of it:
- **Benefit**: Changes to configs in the repo are immediately active (they're sourced live)
- **Workflow**: Edit `dotfiles/.zshrc` → changes apply on next `source ~/.zshrc` or new shell
- **Mechanism**: `setup.sh` appends `source ~/.dotfiles/dotfiles/.zshrc` (via `.zshrc.local`) to `~/.zshrc`
- **No backups**: `setup.sh` does not back up existing files; it appends and relies on the early-exit guard

### Machine-Specific Customization Pattern

The shell configs use a `.local` file pattern for machine-specific settings:

**How it works:**
1. Main config (`dotfiles/.zshrc`) is tracked in git and sourced by `~/.zshrc`
2. `dotfiles/.zshrc.local` (the snippet appended to `~/.zshrc`) is where machine-specific
   PATH additions, aliases, credentials, and cert setup live — it sources `.zshrc` first, then
   layers on overrides
3. Put anything that must NOT be committed directly in `~/.zshrc` below the appended block, or
   keep it out of the repo entirely

**Note:** `dotfiles/.zshrc.local` currently ships in the repo with commented-out examples. There
is no separate `shell/zshrc.local.example` template — the `.local` file itself is the template.

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
vim dotfiles/.zshrc

# Test immediately (config is sourced from the repo)
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

1. Add config file to appropriate directory (`dotfiles/`, `bin/`, etc.)
2. `source` it from `dotfiles/.zshrc` (or `.bashrc`) so it loads — `setup.sh` does not symlink
   individual files
3. Test by opening a new shell or running `source ~/.zshrc`
4. Document in README.md
5. Commit the config file and the updated `.zshrc`

Example:
```bash
# Add new config
echo "config content" > dotfiles/new-config

# Source it from the main config
echo 'source ~/.dotfiles/dotfiles/new-config' >> dotfiles/.zshrc

# Test
source ~/.zshrc

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
- `~/.zshrc.local` (or other `.local` files)

**Instead:**
- Add examples to `shell/zshrc.local.example`
- Document in comments what should go in `.local` files
- Use environment variable placeholders

### Skills Directory

The `skills/` directory is for AI Agent Skills. See `skills/README.md` for structure and guidelines.

**Activation (manual):** Skills are installed with the `skills` CLI
(https://github.com/vercel-labs/skills), which symlinks them into `~/.claude/skills/`.
`setup.sh` does NOT do this — install each skill yourself from the repo root:

```bash
npx skills add ./skills/write-like-me
```

**Configuration (aspirational):**
- `skills/config.toml`: Intended to enable/disable repo skills
- `skills/config.local.toml`: Intended for machine-specific overrides (gitignored)
- `[external_skills].paths` in `config.local.toml`: Intended for skills outside this repo

No tooling currently reads these config files — they document intent. Wiring is manual until a
setup step is added. A valid skill must have a `SKILL.md` file to be recognized by Claude Code.

### Agents Directory

The `agents/` directory contains Claude Code subagents. See `agents/README.md` for structure and guidelines.

**Activation (manual):** An agent is active only once its `.md` file is symlinked into
`~/.claude/agents/`. `setup.sh` does NOT do this — symlink each agent yourself:

```bash
ln -s ~/.dotfiles/agents/code-reviewer.md ~/.claude/agents/code-reviewer.md
```

**Configuration (aspirational):**
- `agents/config.toml`: Intended to enable/disable repo agents
- `agents/config.local.toml`: Intended for machine-specific overrides (gitignored)
- `[external_agents].paths` in `config.local.toml`: Intended for agents outside this repo

No tooling currently reads these config files — they document intent. Wiring is manual until a
setup step is added. Agents must be `.md` files.

## Dependencies

Common dependencies assumed to be available:
- `bash` or `zsh` (shell)
- `aws` CLI (AWS scripts)
- `jq` (JSON processing)
- `openssl` 1.0.0+ with genpkey/pkeyutl (vault)
- `column` (table formatting)
- Python 3 (mutate script)

## Legacy Files

- **setup-path.sh**: Deprecated in favor of `setup.sh`. Old script only handled PATH setup; new script handles all symlinks and configuration.

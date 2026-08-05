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
- Create a `~/.dotfiles` symlink pointing at this repository
- Append `dotfiles/.zshrc.local` to `~/.zshrc` and `dotfiles/.bashrc.local` to `~/.bashrc`

That's all it does. Shell config, PATH, skills, and agents are wired up by those appended
snippets and by manual symlinks — see the sections below. `setup.sh` does **not** symlink
shell configs, create backups, or install skills/agents.

## Repository Structure

```
dotfiles/
├── bin/              # Utility scripts (AWS tools, vault, git helpers)
├── dotfiles/         # Shell configuration files
│   ├── .zshrc        # Main zsh configuration
│   ├── .bashrc       # Main bash configuration
│   ├── .zshrc.local  # zsh snippet appended to ~/.zshrc by setup.sh
│   └── .bashrc.local # bash snippet appended to ~/.bashrc by setup.sh
├── skills/           # AI Agent Skills
├── agents/           # AI Agents
├── setup.sh          # Main setup script
└── README.md         # This file
```

## Configuration Files

### Shell (zsh/bash)

Shell configurations live in the `dotfiles/` directory. `setup.sh` appends the `.local`
snippets to your real rc files:
- `dotfiles/.zshrc.local` → appended to `~/.zshrc`
- `dotfiles/.bashrc.local` → appended to `~/.bashrc`

Those snippets are what source the main configs and add `bin/` to your PATH.

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

### Utility Scripts

All scripts in `bin/` will be available in your PATH after setup. Key utilities:

- **vault** - RSA-encrypted password manager
- **assume-role** - AWS STS role assumption helper
- **ec2s** - Filter EC2 instances by tag
- **subnet-ips** - Analyze AWS subnet IP usage
- **kms-keys** - List KMS keys with aliases
- **git-summary** - Show recent git commits in a formatted table
- **zip-skills** - Package skills into zips for upload to Claude Cowork/other editors
- **mutate** - Text mutation utility
- **ansi_colors** - ANSI color reference

See `bin/` directory for full list. Most scripts include usage information when run without arguments.

## Manual Setup

If you prefer not to use the automated setup script:

1. Create the repo symlink:
   ```bash
   ln -s ~/workspace/dotfiles ~/.dotfiles
   ```

2. Source the config from your rc files (this also adds `bin/` to PATH):
   ```bash
   echo 'source ~/.dotfiles/dotfiles/.zshrc' >> ~/.zshrc
   echo 'source ~/.dotfiles/dotfiles/.bashrc' >> ~/.bashrc
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

**Activating skills** (`setup.sh` does not do this — install manually).

Skills are managed with the [`skills`](https://github.com/vercel-labs/skills) CLI, which
symlinks each skill into `~/.claude/skills/` (and other agents' dirs, e.g. Cursor):

```bash
# Install one skill from this repo (run from the repo root)
npx skills add ./skills/write-like-me

# Install every skill in this repo
for s in skills/*/; do [ -f "$s/SKILL.md" ] && npx skills add "./$s"; done

# Manage
npx skills list          # show installed skills
npx skills update        # upgrade installed skills
npx skills remove <name> # uninstall
```

To install community skills instead of local ones, use `npx skills find` or
`npx skills add owner/repo`. See the [CLI docs](https://github.com/vercel-labs/skills).

**Packaging skills for upload** — some clients (Claude Cowork, claude.ai, other editors) take a
skill as a zip upload rather than a symlink. Use `zip-skills` to build those archives:

```bash
zip-skills                 # interactive picker (Up/Down, Space toggle, a = all, Enter)
zip-skills --all           # zip every skill, no prompts
zip-skills write-like-me   # zip specific skill(s) by name
zip-skills --list          # list available skills
zip-skills --clean         # delete the zips in the output directory
```

Each skill becomes its own `<name>.zip`, with the skill directory at the archive root
(e.g. `write-like-me/SKILL.md`).

Paths:

- **Skills** are read from the current directory — `./skills/` if it exists, otherwise the current
  directory itself when it holds the skill folders. If neither matches, you are prompted for a
  path. Override with `-s, --skills-dir PATH`.
  A prompted path and `--skills-dir` are resolved the same way as the current directory, so either
  a repo root (containing `skills/`) or a skills directory itself works.
- **Zips** are written to `~/skills` by default. Override with `-o, --output PATH`.

Since the script works off the current directory, it packages any skills collection, not just this
repo's:

```bash
cd ~/.dotfiles && zip-skills --all              # this repo's skills
zip-skills -s ~/other-project --all             # another repo (finds its skills/)
zip-skills -s ~/other-project/skills --all      # or point straight at a skills dir
zip-skills --all -o ~/Desktop/skill-uploads     # custom output
```

When the skills directory is inside a git repo, the file list comes from git, so anything ignored
by `.gitignore` is left out of the archive — that keeps private material like
`skills/write-like-me/samples/` from being uploaded, and per-skill `.gitignore` files are stripped
too. Outside a git repo there are no ignore rules to apply, so every file is packaged and the
script warns you to check the archives before uploading.

**Activating agents** (manual — no CLI for these yet):

```bash
# Symlink an agent's .md file into ~/.claude/agents/
ln -s ~/.dotfiles/agents/code-reviewer.md ~/.claude/agents/code-reviewer.md
```

The `config.toml` files in `skills/` and `agents/` document which resources are intended to be
enabled; `config.local.toml` (gitignored) is reserved for machine-specific overrides. Nothing
reads them automatically yet.

## Dependencies

Common tools used by scripts:
- **aws** CLI (for AWS scripts)
- **jq** (JSON processing)
- **openssl** 1.0.0+ (for vault script)
- **node** 18+ / **npx** (for the `skills` CLI, used to install AI Agent Skills)

## Legacy Setup Script

The old `setup-path.sh` script is deprecated in favor of the new `setup.sh` script. If you previously used `setup-path.sh`, you can safely remove the PATH export it added to your shell profile, as the new symlinked configs handle this automatically.

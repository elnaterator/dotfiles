# AI Agents (Subagents)

This directory contains custom subagents for Claude Code.

## What are Subagents?

Subagents are specialized AI agents that can be invoked to perform complex, multi-step tasks. They are autonomous systems that maintain context, make decisions, and execute workflows independently. Unlike skills (which are invoked for specific operations), subagents can handle entire workflows.

## Directory Structure

```
agents/
├── README.md                  # This file
└── [agent-name].md            # Individual subagent markdown files
```

Each subagent is a single markdown file with YAML frontmatter.

## File Format

Subagents use markdown files with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Expert code review specialist for quality, security, and maintainability
tools: Read, Grep, Glob, Bash
model: sonnet
---

# System Prompt

You are an expert code reviewer focused on...
[Your detailed system prompt goes here]
```

### Required Fields
- `name`: Unique identifier for the subagent
- `description`: Brief description of what the subagent does

### Optional Fields
- `tools`: Comma-separated list of tools the subagent can use (Read, Grep, Glob, Bash, etc.)
- `model`: Which model to use (`sonnet`, `opus`, `haiku`, or `inherit`)

## Adding New Subagents

To add a new subagent:

1. Create a markdown file in this directory: `agents/my-agent.md`
2. Add YAML frontmatter with name, description, and optional configuration
3. Write the system prompt in the markdown body
4. Run `./setup.sh` to symlink it to `~/.claude/agents/`

Example:

```bash
# Create new subagent
cat > agents/test-writer.md << 'EOF'
---
name: test-writer
description: Specialized agent for writing comprehensive test suites
tools: Read, Write, Bash, Grep
model: sonnet
---

You are a testing expert specialized in writing comprehensive test suites.
Your goal is to create thorough, maintainable tests that cover edge cases.
EOF

# Run setup to symlink
./setup.sh
```

## Organization

You can organize subagents by creating subdirectories:
```
agents/
├── README.md
├── development/
│   ├── code-reviewer.md
│   └── refactoring-specialist.md
└── devops/
    ├── kubernetes-expert.md
    └── ci-cd-specialist.md
```

The setup script will symlink all `.md` files recursively to `~/.claude/agents/`.

## Using Subagents

Once symlinked to `~/.claude/agents/`, subagents can be invoked in Claude Code using the Task tool with the subagent name.

## References

- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Example Subagents Repository](https://github.com/VoltAgent/awesome-claude-code-subagents)

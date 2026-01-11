# AI Agent Skills

This directory contains custom skills for AI agents like Claude Code.

## What are Skills?

Skills are reusable, specialized capabilities that can be invoked by AI agents to perform specific tasks. They extend the agent's functionality beyond its base capabilities.

## Directory Structure

```
skills/
├── README.md          # This file
└── [skill-name]/      # Individual skill directories
    ├── skill.json     # Skill definition and metadata
    ├── README.md      # Skill documentation
    └── ...            # Skill implementation files
```

## Adding New Skills

To add a new skill:

1. Create a new directory for your skill
2. Add a `skill.json` file with skill metadata
3. Add a `README.md` documenting the skill's purpose and usage
4. Implement the skill functionality

## Example Skill Structure

```json
{
  "name": "example-skill",
  "version": "1.0.0",
  "description": "An example skill demonstrating the structure",
  "author": "Your Name",
  "triggers": ["keyword", "phrase"],
  "parameters": []
}
```

## Using Skills

Skills can be invoked by AI agents when they recognize relevant triggers or when explicitly called. Refer to individual skill documentation for usage details.

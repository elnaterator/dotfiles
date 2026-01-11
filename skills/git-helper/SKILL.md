---
name: git-helper
description: |
  Git workflow assistant for common tasks. Use this skill when the user asks to:
  - Create a commit with proper conventional commit formatting (feat, fix, docs, style, refactor, test, chore)
  - Create a new feature or fix branch with consistent naming
  - Create a pull request with well-formatted description
  - Check git status, view recent history, or review uncommitted changes
  - Follow git best practices for commits and branching
  This skill ensures atomic commits, descriptive messages, conventional commit format, and includes AI co-author attribution.
---

# Git Helper Skill

A comprehensive git workflow assistant that helps with commits, branches, and pull requests following best practices.

## Core Principles

1. **Follow conventional commits** - Always use the conventional commit format
2. **Be atomic** - Each commit should represent one logical change
3. **Be descriptive** - Clear messages that explain the "why" not just the "what"
4. **Include co-author** - Add AI co-author attribution when creating commits
5. **Check before acting** - Always check status and diff before committing

## Workflow: Creating a Commit

When user asks to create a commit:

### 1. Check Status
```bash
git status
git diff --staged
git diff
```

### 2. Analyze Changes
- Review what files changed
- Understand the nature of the changes
- Determine appropriate commit type

### 3. Determine Commit Type
- `feat:` - New functionality added
- `fix:` - Bug fixes
- `docs:` - Documentation only changes
- `style:` - Formatting, whitespace, no code changes
- `refactor:` - Code restructuring without changing behavior
- `test:` - Test additions or updates
- `chore:` - Build process, configs, maintenance

### 4. Draft Message
Format:
```
<type>: <short description>  (max 72 chars)

Optional body explaining why this change was made

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### 5. Stage & Commit
```bash
git add <files>
git commit -m "$(cat <<'EOF'
feat: add user authentication

Implement JWT-based authentication to secure API endpoints.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
git status  # Verify commit succeeded
```

## Workflow: Branch Management

When user asks to create or manage branches:

### 1. Check Current State
```bash
git status
git branch -vv
```

### 2. Suggest Branch Name
Format: `<type>/<short-description>`
- Types: `feature/`, `fix/`, `refactor/`, `docs/`
- Examples: `feature/user-auth`, `fix/login-bug`, `docs/api-guide`

### 3. Create Branch
```bash
git checkout -b feature/new-feature
git push -u origin feature/new-feature
```

## Workflow: PR Creation

When user asks to create a pull request:

### 1. Review Branch Changes
```bash
git status
git log main..HEAD
git diff main...HEAD
```

### 2. Generate PR Content
Structure:
- **Title**: Clear, concise description of the change
- **Summary**: Bullet points of what changed and why
- **Test plan**: Checklist of how to verify changes
- **Related issues**: Link any relevant issues

### 3. Create PR
```bash
gh pr create --title "Add user authentication" --body "$(cat <<'EOF'
## Summary
- Implement JWT-based authentication
- Add login/logout endpoints
- Secure protected routes with middleware

## Test plan
- [ ] Test login with valid credentials
- [ ] Test login with invalid credentials
- [ ] Verify protected routes require authentication
- [ ] Test logout functionality
- [ ] Verify token expiration handling

## Related issues
Closes #123

🤖 Generated with Claude Code
EOF
)"
```

## Workflow: Status Check

When user asks for git status or history:

### 1. Show Comprehensive Status
```bash
git status
git log --oneline -10
git branch -vv
```

### 2. Provide Summary
Include:
- Current branch name
- Uncommitted changes (staged and unstaged)
- Recent commits (last 5-10)
- Upstream tracking status
- Any merge conflicts or special states

## Error Handling

- **No changes staged**: Ask user what files to stage
- **Commit fails**: Check for pre-commit hooks, show error, suggest fix
- **Branch already exists**: Suggest alternative name or offer to switch
- **No GitHub remote**: Warn that PR creation requires GitHub setup
- **Merge conflicts**: Guide user through resolution process

## Important Notes

- **NEVER** skip git hooks unless explicitly requested by user
- **NEVER** force push to main/master branches
- **ALWAYS** include co-author attribution for AI-assisted commits
- **ALWAYS** check diff before committing to avoid unintended changes
- **ASK** user for clarification if commit message or scope is unclear

## Examples

### Example 1: Simple Feature Commit
```bash
# User: "Help me commit these changes"
git status
git diff --staged

# Analyze: Added new login form component
# Type: feat (new feature)
# Message: "feat: add login form component"

git commit -m "$(cat <<'EOF'
feat: add login form component

Add reusable login form with email/password validation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

### Example 2: Bug Fix with Branch
```bash
# User: "Create a branch to fix the navbar bug"
git checkout -b fix/navbar-alignment

# Make fixes...
git add src/components/Navbar.tsx
git commit -m "$(cat <<'EOF'
fix: correct navbar alignment on mobile

Center logo and adjust padding for screens < 768px.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

git push -u origin fix/navbar-alignment
```

### Example 3: Documentation Update
```bash
# User: "Commit the README changes"
git diff README.md

# Type: docs (documentation only)
git add README.md
git commit -m "$(cat <<'EOF'
docs: update installation instructions

Add troubleshooting section for common npm install errors.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

## Dependencies

- `git` - Git version control system
- `gh` - GitHub CLI (optional, for PR creation)

## Best Practices Enforced

This skill follows these git best practices:
- Atomic commits (one logical change per commit)
- Descriptive commit messages following conventional commits
- Clear PR descriptions with test plans
- Proper branch naming conventions
- Co-author attribution for AI assistance
- Verification after operations (git status checks)

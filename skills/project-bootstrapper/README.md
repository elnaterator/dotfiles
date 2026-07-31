# project-bootstrapper

Scaffolds new projects — and upgrades existing ones — to a consistent, opinionated layout.

## What it gives every project

- **README.md** — value-first overview, quick start, config (when applicable), usage.
- **CONTRIBUTING.md** — dev setup, make commands, branch/commit/PR conventions.
- **AGENTS.md** — single source of truth for AI-agent guidance.
- **CLAUDE.md** — thin pointer to AGENTS.md.
- **Makefile(s)** — standard `run` / `test` / `build` / `lint` / `clean` + `help`.
- **docs/** — only when the project needs docs beyond the README.
- **.gitignore** — language-appropriate (+ Terraform when infra is included).

## Languages

- **Python** (uv) — ruff, mypy, bandit + pip-audit, pytest w/ coverage, pre-commit hooks, CI workflow,
  runnable source + test stubs
- **Java** (Gradle, Kotlin DSL) — spotless, SpotBugs + find-sec-bugs, OSV-Scanner, JUnit + JaCoCo
  (80% gate), pre-commit, CI, source + test stubs
- **Go** — golangci-lint v2 (incl. gosec + gofumpt/goimports), govulncheck, coverage gate (80%),
  pre-commit, CI, source + test stubs
- **Any other** — still gets the docs + a sensible Makefile and layout.

## Terraform infra (optional)

When infra is included, source moves into a subdir with its own Makefile, infra lives in `infra/` with
its own Makefile (fixed `environments/{dev,prd}` + `modules/` layout), and a lean root Makefile spans
both (`run`/`test`/`check`). Infra toolchain: terraform fmt, tflint, Trivy (security), terraform
validate, and native `terraform test` — all wired into `make check`.

## Modes

- **New** — a short wizard (name, language, infra?, docs?, value prop) then scaffolds the tree.
- **Update** — detects what's missing and adds only that, non-destructively.

## Usage

Ask Claude Code:

- "bootstrap a new python project called foo with terraform infra"
- "scaffold a go service"
- "add my standard docs and Makefile to this repo"
- "set up AGENTS.md + CLAUDE.md here"

## Layout

```
project-bootstrapper/
├── SKILL.md
├── README.md
└── templates/
    ├── docs/            # README / CONTRIBUTING / AGENTS / CLAUDE templates
    ├── python-uv/       # Makefile + pyproject.toml
    ├── java-gradle/     # Makefile (wraps gradlew)
    ├── golang/          # Makefile + go.mod
    ├── infra-terraform/ # Makefile + starter .tf files
    └── makefiles/       # root delegating Makefile (infra layout)
```

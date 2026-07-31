---
name: project-bootstrapper
description: |
  Bootstraps and upgrades software projects to the user's preferred conventions. Use this skill when
  the user asks to:
  - Start / scaffold / bootstrap a brand-new project ("bootstrap a python project", "new go service",
    "scaffold a java gradle app", "start a project with terraform infra")
  - Bring an existing project up to their standards ("add the standard docs/makefile", "set up
    AGENTS.md + CLAUDE.md", "add terraform infra layout", "make this project follow my conventions")
  Supports Python (uv), Java (Gradle), Go, and any other language. Optionally adds Terraform infra
  (source in a subdir, infra in infra/). Always adds README, CONTRIBUTING, AGENTS.md, a CLAUDE.md that
  points at AGENTS.md, and Makefiles with standard run/test/build targets. Docs go under docs/.
---

# Project Bootstrapper

Scaffold new projects — or upgrade existing ones — to a consistent, opinionated layout. Two modes:
**new** (wizard-driven scaffold) and **update** (detect gaps, add missing pieces non-destructively).

Templates live in `templates/` next to this file. Copy them, replace the `{{PLACEHOLDERS}}`, never ship
a template with placeholders left in.

## The conventions (what every project ends up with)

Applies regardless of language:

- **README.md** — overview first. Make the *value* of the project obvious (why it exists / who it helps),
  then Quick Start, then Configuration (only when the project has config), then Usage.
- **CONTRIBUTING.md** — a normal contributing doc: dev setup, how to build/test/lint, branch + commit
  conventions, PR process.
- **AGENTS.md** — the single source of truth for AI-agent guidance (overview, structure, commands,
  conventions).
- **CLAUDE.md** — thin file that points at AGENTS.md; no duplicated content.
- **Makefile(s)** — standard targets: `run`, `test`, `build`, plus language-appropriate `lint`/`format`/
  `install`/`clean`. A `help` default target, and a **`check`** target that formats, lints, builds, then
  runs tests (the pre-commit gate). **`check` is CI-aware**: locally it runs the mutating `format`
  target (rewrites files); under CI (`CI` env var set — GitHub Actions sets it automatically) it runs a
  non-mutating `format-check`/`fmt-check` that **fails** on drift, so CI catches unformatted code that
  bypassed the commit hook. The commit hook always auto-fixes formatting; CI only verifies.
- **docs/** — only when the project needs more than the README. Deeper docs go here, not in the README.
- **.gitignore** — appropriate for the language (+ Terraform if infra).

## Layout

**No infra** — one Makefile at the root:

```
<project>/
├── Makefile           # run / test / build / lint / clean
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md
├── CLAUDE.md
├── docs/              # only if needed
└── <language source>  # e.g. src/, cmd/, app/
```

**With infra** — source moves into a subdir, infra in `infra/`, and the root Makefile delegates to both:

```
<project>/
├── Makefile           # lean: run / test / check span src + infra
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md
├── CLAUDE.md
├── docs/              # only if needed
├── <src-dir>/         # source subdir (src/ python, app/ java, cmd|. go — ask if unclear)
│   ├── Makefile       # the language Makefile (run/test/build/lint)
│   └── <source files>
└── infra/
    ├── Makefile       # ENV-aware: make plan ENV=dev
    ├── .tflint.hcl    # tflint config
    ├── environments/
    │   ├── dev/       # main.tf (calls modules) + variables/outputs/tfvars
    │   └── prd/
    └── modules/
        └── <module>/  # main.tf + variables.tf + outputs.tf
            └── tests/ # <name>.tftest.hcl (native terraform test)
```

Infra layout is fixed: **always** `environments/{dev,prd}` (per-env root modules that wire up the
shared modules) and `modules/<name>` (reusable modules). The infra Makefile targets one environment
at a time via `ENV`/`env` (default `dev`): `make plan ENV=prd`.

Infra toolchain (parity with the languages): **terraform fmt** (format), **tflint** (lint, config in
`.tflint.hcl`), **Trivy** `config` (IaC misconfiguration/security scan), **terraform validate**, and
native **`terraform test`** (`.tftest.hcl` files under `modules/<name>/tests/`). `make check` runs
fmt + lint + security + validate + test (like the languages, `check` runs mutating `fmt` locally and
non-mutating `fmt-check` under CI). Ships an example testable `modules/example/` (local +
output + a `.tftest.hcl`) and `.github/workflows/infra.yml` (installs terraform/tflint/trivy, runs
`make check`). **tflint and Trivy are external CLIs** — `make tools` installs them via Homebrew; CI
installs pinned versions. Whole-tree targets (fmt/lint/security/test) cover all envs + modules;
plan/apply/destroy/validate are per-env.

Rule: the language Makefile is the *same file* whether it sits at the repo root (no infra) or in the
source subdir (with infra). Only the root delegating Makefile is infra-specific — and it stays **lean**:
just `run`, `test`, `check`, spanning both `src` and `infra` (test also runs `terraform validate`;
check runs both sub-`check`s). Infra `plan`/`apply`/`destroy` are not surfaced at the root — run them
in `infra/` directly: `make -C infra apply ENV=prd`.

## Mode: NEW project (wizard)

Run a short wizard with the `AskUserQuestion` tool. Ask only what you can't already infer from the
request. Questions:

1. **Project name** (and target directory if not the cwd).
2. **Language** — Python (uv) / Java (Gradle) / Go / Other. If "Other", ask what, and adapt: still
   produce the docs, a sensible Makefile with `run`/`test`/`build`, and the infra layout on request.
   For **Python**, **Java**, and **Go**, also ask **app/service vs library** — it drives the
   language-version floor (see each language's version policy below).
3. **Terraform infra?** — yes/no. If yes, apply the with-infra layout.
4. **Docs dir?** — will this need a `docs/` tree beyond the README? Default no.
5. **One-line value proposition + short description** — for the README overview. If the user already
   said what it's for, skip and confirm.

Then scaffold:

1. Create the directory tree for the chosen layout.
2. Copy language templates from `templates/<lang>/`, fill placeholders.
3. Copy doc templates from `templates/docs/`, fill placeholders (value prop, quick start, config).
4. If infra: copy `templates/infra-terraform/` into `infra/` (its `Makefile` and `.tflint.hcl`). Copy
   the `environments/env/` template into `environments/dev/` and `environments/prd/`, filling `{{ENV}}`
   in each. Keep `modules/example/` or rename it to a real first module. Then use
   `templates/makefiles/Makefile.root-delegating` at the root (set `SRC_DIR`); the language Makefile
   goes in the source subdir.
5. If no infra: the language Makefile is the root Makefile.
6. Language-specific init commands (below) — run them or print them for the user.
7. `git init` if not already a repo. Do **not** commit unless asked.
8. Summarize what was created and the key `make` targets.

## Mode: UPDATE existing project

1. Inspect the repo: language, existing `README`/`CONTRIBUTING`/`AGENTS.md`/`CLAUDE.md`/`Makefile`,
   whether `infra/` exists, whether source is already in a subdir.
2. Report the gaps vs. the conventions above.
3. Add **only what's missing**. Never overwrite an existing file without showing the diff and asking.
   For an existing README, offer to restructure toward the overview-first shape rather than clobbering.
4. If adding infra to a project whose source is at the root, moving source into a subdir is a big
   change — propose it, confirm before moving, and update the Makefiles accordingly.
5. Keep it minimal and reversible; summarize every change.

## Placeholders

Replace across all copied templates:

- `{{PROJECT_NAME}}` — project / repo name
- `{{PROJECT_DESCRIPTION}}` — one-paragraph description
- `{{ONE_LINE_VALUE_PROP}}` — the "why this exists" tagline
- `{{PACKAGE}}` — Python import package (snake_case) / Java package (e.g. `com.example.myapp`)
- `{{GROUP}}` — Java Gradle group id (e.g. `com.example`)
- `{{MODULE_PATH}}` — Go module path (e.g. `github.com/user/repo`)
- `{{BINARY_NAME}}` — Go/compiled binary name
- `{{SRC_DIR}}` — source subdir when infra is present (`src`, `app`, `cmd`, …)

## Language notes

**Python (uv)** — `templates/python-uv/`. Layout: `src/{{PACKAGE}}/` with `__init__.py` + `main.py`,
`tests/`. After scaffolding: `uv sync`. Tooling: **ruff** (format + lint), **mypy** (types),
**bandit** + **pip-audit** (security) — all configured in `pyproject.toml`. Makefile targets:
`install` (`uv sync` + install hooks), `hooks`, `run`, `test` (`pytest` w/ coverage), `format`,
`format-check` (CI verify-only), `lint`, `security`, `build` (`uv build`), `check`.

The Python template also ships: `.python-version`, `.gitignore`, `.editorconfig`,
`.pre-commit-config.yaml` (ruff/mypy/bandit hooks), `.github/workflows/ci.yml` (runs `make check`),
runnable source stubs in `src/package/` (`__init__.py`, `__main__.py`, `main.py`, `py.typed`), and a
sample `tests/test_main.py`. When scaffolding: copy the whole `python-uv/` tree, **rename the
`src/package/` dir to `src/{{PACKAGE}}/`**, strip `.tmpl` suffixes and fill placeholders, then
`uv sync` (which also installs the pre-commit hooks). `pyproject.toml` sets a coverage `fail_under`
(80) and ruff/mypy/bandit config — no separate config files. Keep the `.pre-commit-config.yaml`
`rev`s roughly aligned with the `pyproject.toml` dev-dep versions.

**Python version policy** — the template ships the latest stable (3.14) in `.python-version`,
`requires-python`, and `[tool.mypy].python_version`. Choose by project type:
- **App / service** (the default) — keep the latest stable across all three. It's not a dependency of
  anything, so a high floor costs nothing.
- **Library** (published / imported by others) — set `requires-python = ">=3.11"` and mypy
  `python_version = "3.11"` so consumers on older Pythons can install it, but keep `.python-version`
  at the latest stable for local dev. Ask (or infer) whether it's a lib when bootstrapping Python.

**Java (Gradle)** — `templates/java-gradle/`. Kotlin-DSL build with an opinionated toolchain:
**Spotless** + google-java-format (format), **SpotBugs** + **find-sec-bugs** (lint + SAST security),
**OSV-Scanner** (dependency CVEs), **JUnit Jupiter** (test), **JaCoCo** with an 80% coverage gate.
Java toolchain pinned to the latest **LTS (25)**.

The template has no gradle wrapper (binary) — generate it first, then overlay the template:
1. `gradle wrapper --gradle-version 9.6.1` (or `gradle init`) to create `gradlew` + `gradle/wrapper/`.
2. Copy the template files, renaming `src/main/java/pkg/` and `src/test/java/pkg/` to your
   `{{PACKAGE}}` path (e.g. `com/example/myapp`), strip `.tmpl`, fill placeholders.
3. `make deps-lock` to write `gradle.lockfile` (OSV-Scanner needs it), then `make check`.

Ships: `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`, `.gitignore`, `.editorconfig`,
`.pre-commit-config.yaml` (spotless local hook), `.github/workflows/ci.yml` (runs `make check`),
`App.java` + `AppTest.java` stubs. Makefile targets: `run`, `test`, `format`, `format-check` (CI
verify-only), `lint`, `security`, `build`, `check`, `deps-lock`, `hooks`, `clean`. **OSV-Scanner is an external CLI** — install it
(`brew install osv-scanner`) or the `security` target fails; CI installs it in a step.

**Java version policy** — the toolchain defaults to the latest LTS (25) in `build.gradle.kts`.
- **App / service** — keep the latest LTS.
- **Library** — lower `JavaLanguageVersion.of(...)` (or add a `release` compile option) to an older
  widely-available LTS (e.g. 21) so consumers on older JDKs can use it. Ask (or infer) whether it's a
  library when bootstrapping Java.

**Go** — `templates/golang/`. Opinionated toolchain: **golangci-lint v2** (lint incl. **gosec** SAST,
plus format via **gofumpt** + **goimports**), **govulncheck** (dependency + stdlib CVEs), `go test`
with an 80% coverage gate. `go` directive pinned to the latest stable (1.26). The coverage gate
measures `COVER_PKG` (default `./internal/...`) so the thin `main` entrypoint doesn't drag the
number — widen it (`make coverage COVER_PKG=./...`) or edit the Makefile as the project grows.
**Set `COVER_PKG` to packages that actually exist in the scaffolded layout**: if the project has no
`internal/` tree, the default matches nothing and `make coverage` errors ("no coverage data"). Pick
the real business-logic packages when bootstrapping.

Scaffold:
1. `go mod init {{MODULE_PATH}}` (or fill `go.mod.tmpl`).
2. Copy the template; layout is `main.go` at the root calling `internal/greeting/` (a testable
   package + test). Fill `{{MODULE_PATH}}` / `{{BINARY_NAME}}`, strip `.tmpl`.
3. `make tools` to install golangci-lint + govulncheck, then `make check`.

Ships: `go.mod`, `.golangci.yml`, `.gitignore`, `.editorconfig`, `.pre-commit-config.yaml`
(golangci-lint local hooks), `.github/workflows/ci.yml` (runs `make check`), `main.go` +
`internal/greeting/` stub + test. Makefile targets: `deps`, `run`, `test`, `coverage`, `format`,
`format-check` (CI verify-only), `lint`, `security`, `build`, `check`, `tools`, `hooks`, `clean`. **golangci-lint and govulncheck are
external CLIs** — `make tools` installs them; CI runs `make tools` first.

**Go version policy** — Go has no LTS; the `go.mod` directive defaults to the latest stable (1.26).
- **App / service** — keep the latest stable.
- **Library** — set the `go` directive to an older still-supported minor (Go supports the last two,
  e.g. 1.25) so consumers on older toolchains can build it. Ask (or infer) whether it's a library.

**Other** — no template. Still create all docs and a Makefile with at least `run`/`test`/`build`/`help`
matching the language's toolchain, plus the infra layout if requested.

## .gitignore

Start from the language default and add, when infra is present:

```
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
.terraform.lock.hcl
crash.log
```

Per-language essentials — Python: `.venv/ __pycache__/ dist/ build/ *.egg-info/ .pytest_cache/
.mypy_cache/ .ruff_cache/`. Go: `bin/ *.exe`. Java/Gradle: `.gradle/ build/`.

## Notes

- Never leave `{{PLACEHOLDERS}}` in generated files.
- Drop the README **Configuration** section entirely when the project has no config options.
- Don't commit or push unless the user asks.
- Keep CLAUDE.md thin — it points at AGENTS.md, it does not duplicate it.
- **Tune the Makefile to the real layout you scaffolded.** Templates assume the stub structure
  (`src/`, `internal/`, `app/`, …); if you deviate, update the affected targets — source/test paths in
  `lint`/`format`, `COVER_PKG` for Go coverage, the `run` entrypoint, `clean` paths — so they point at
  directories that exist. A target aimed at a missing dir fails on first run.
- **LICENSE** — not scaffolded by default. If the user names a license, add the matching `LICENSE`
  file and set the license field in the manifest (`pyproject.toml` / `build.gradle.kts` / module docs).

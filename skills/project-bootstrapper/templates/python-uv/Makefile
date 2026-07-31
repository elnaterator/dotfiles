# In CI the check gate must FAIL on formatting drift; locally it rewrites files.
# GitHub Actions (and most CI) set CI=true automatically.
FMT_TARGET := $(if $(CI),format-check,format)

.DEFAULT_GOAL := help
.PHONY: help install hooks run test lint format format-check security build check clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "; blue = sprintf("%c[34m", 27); reset = sprintf("%c[0m", 27)} {printf "  %s%-15s%s %s\n", blue, $$1, reset, $$2}'

install: ## Sync dependencies and install git hooks
	uv sync
	uv run pre-commit install

hooks: ## Install/refresh pre-commit git hooks
	uv run pre-commit install

run: ## Run the application
	uv run python -m {{PACKAGE}}

test: ## Run the test suite
	uv run pytest

lint: ## Lint the code (ruff + mypy)
	uv run ruff check src tests
	uv run mypy src

format: ## Format the code (ruff)
	uv run ruff format src tests

format-check: ## Verify formatting without rewriting (CI gate)
	uv run ruff format --check src tests

security: ## Security scan (bandit SAST + pip-audit deps)
	uv run bandit -r src
	uv run pip-audit

build: ## Build distributable artifacts
	uv build

check: $(FMT_TARGET) lint security build test ## Format (verify-only in CI), lint, scan, build, then test (pre-commit gate)

clean: ## Remove build artifacts and caches
	rm -rf dist build *.egg-info .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +

.DEFAULT_GOAL := help
GRADLE := ./gradlew
# In CI the check gate must FAIL on formatting drift; locally it rewrites files.
# GitHub Actions (and most CI) set CI=true automatically.
FMT_TARGET := $(if $(CI),format-check,format)
.PHONY: help run test format format-check lint security build check clean deps-lock hooks

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

run: ## Run the application
	$(GRADLE) run

test: ## Run the test suite (JUnit) + coverage report
	$(GRADLE) test

format: ## Format the code (spotless + google-java-format)
	$(GRADLE) spotlessApply

format-check: ## Verify formatting without rewriting (CI gate)
	$(GRADLE) spotlessCheck

lint: ## Lint (spotless check + SpotBugs)
	$(GRADLE) spotlessCheck spotbugsMain spotbugsTest

security: ## Security scan (SpotBugs+find-sec-bugs SAST, OSV-Scanner deps)
	$(GRADLE) spotbugsMain
	osv-scanner --lockfile=gradle.lockfile

build: ## Build artifacts
	$(GRADLE) build

check: $(FMT_TARGET) lint security build test ## Format (verify-only in CI), lint, scan, build, then test (pre-commit gate)

deps-lock: ## Write/refresh the dependency lockfile (for OSV-Scanner)
	$(GRADLE) dependencies --write-locks

hooks: ## Install pre-commit git hooks
	pre-commit install

clean: ## Remove build artifacts
	$(GRADLE) clean

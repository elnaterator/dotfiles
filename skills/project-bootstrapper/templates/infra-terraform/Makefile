# Terraform infra Makefile. Environment-scoped targets run against one env at a time:
#   make plan ENV=dev      make apply env=prd
# Whole-tree targets (fmt, lint, security, test) cover all environments + modules.
ENV ?= dev
ifdef env
ENV := $(env)
endif
ENV_DIR := environments/$(ENV)
TF := terraform -chdir=$(ENV_DIR)
# In CI the check gate must FAIL on formatting drift; locally it rewrites files.
# GitHub Actions (and most CI) set CI=true automatically.
FMT_TARGET := $(if $(CI),fmt-check,fmt)

.DEFAULT_GOAL := help
.PHONY: help init fmt fmt-check lint security validate test plan apply destroy check clean tools

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the environment (providers + backend)
	$(TF) init

fmt: ## Format all Terraform files (whole tree)
	terraform fmt -recursive

fmt-check: ## Verify formatting without rewriting (CI gate)
	terraform fmt -recursive -check

lint: ## Lint with tflint (whole tree, uses .tflint.hcl)
	tflint --init
	tflint --recursive

security: ## IaC misconfiguration scan (trivy)
	trivy config .

validate: ## Validate the environment configuration
	$(TF) init -backend=false
	$(TF) validate

test: ## Run native terraform tests across modules
	@for d in $$(find modules -name '*.tftest.hcl' -exec dirname {} \; | sed 's:/tests$$::' | sort -u); do \
		echo "== terraform test: $$d =="; \
		terraform -chdir="$$d" init -backend=false >/dev/null; \
		terraform -chdir="$$d" test; \
	done

plan: ## Show an execution plan for ENV
	$(TF) plan

apply: ## Apply changes to ENV
	$(TF) apply

destroy: ## Tear down ENV
	$(TF) destroy

check: $(FMT_TARGET) lint security validate test ## Format (verify-only in CI), lint, scan, validate, test (pre-commit gate)

tools: ## Install infra tools (tflint, trivy) — prefers Homebrew
	brew install tflint trivy

clean: ## Remove local Terraform state/cache
	find environments modules -type d -name .terraform -prune -exec rm -rf {} +
	find environments modules -type f -name .terraform.lock.hcl -delete

.DEFAULT_GOAL := help
BINARY := {{BINARY_NAME}}
COVER_THRESHOLD := 80
# Packages the coverage gate measures. Defaults to library/business code, excluding the
# thin main entrypoint. Widen (e.g. ./...) or narrow as the project grows.
COVER_PKG := ./internal/...
# In CI the check gate must FAIL on formatting drift; locally it rewrites files.
# GitHub Actions (and most CI) set CI=true automatically.
FMT_TARGET := $(if $(CI),format-check,format)
.PHONY: help deps run test coverage format format-check lint security build check clean tools hooks

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

deps: ## Download and tidy modules
	go mod tidy

run: ## Run the application
	go run .

test: ## Run tests
	go test ./...

coverage: ## Run tests with coverage and enforce the threshold
	go test -coverpkg=$(COVER_PKG) -coverprofile=coverage.out ./...
	@total=$$(go tool cover -func=coverage.out | awk '/^total:/ {sub(/%/,"",$$3); print $$3}'); \
		if [ -z "$$total" ]; then echo "no coverage data for COVER_PKG=$(COVER_PKG) — point it at packages that exist"; exit 1; fi; \
		echo "total coverage: $$total% (min $(COVER_THRESHOLD)%)"; \
		awk "BEGIN{exit !($$total+0 >= $(COVER_THRESHOLD))}" || { echo "coverage below $(COVER_THRESHOLD)%"; exit 1; }

format: ## Format the code (golangci-lint: gofumpt + goimports)
	golangci-lint fmt

format-check: ## Verify formatting without rewriting (CI gate)
	golangci-lint fmt --diff

lint: ## Lint the code (golangci-lint, includes gosec)
	golangci-lint run

security: ## Dependency + stdlib vulnerability scan (govulncheck)
	govulncheck ./...

build: ## Build the binary into bin/
	go build -o bin/$(BINARY) .

check: $(FMT_TARGET) lint security build coverage ## Format (verify-only in CI), lint, scan, build, then test+coverage

tools: ## Install dev tools (golangci-lint, govulncheck)
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.2
	go install golang.org/x/vuln/cmd/govulncheck@latest

hooks: ## Install pre-commit git hooks
	pre-commit install

clean: ## Remove build and coverage artifacts
	rm -rf bin coverage.out

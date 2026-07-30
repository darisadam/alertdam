# =============================================================================
# AlertDam — Makefile
#
# `make verify` runs the same checks CI runs. If it passes locally, CI should
# pass too; if the two ever diverge, that is a bug in this file.
# =============================================================================

.DEFAULT_GOAL := help

BINARY_NAME := alertdam
BACKEND_DIR := ./backend
WEB_DIR     := ./web
MOBILE_DIR  := ./mobile
IMAGE       := alertdam:latest

# Pinned tool versions. Keep in sync with .tool-versions and the repository
# variables of the same name used by the workflows.
LEFTHOOK_VERSION      := 2.1.10
GOLANGCI_LINT_VERSION := v2.12.2
GITLEAKS_VERSION      := 8.30.1

GOBIN := $(shell go env GOPATH)/bin
export PATH := $(GOBIN):$(PATH)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Aggregate
# -----------------------------------------------------------------------------
verify: fmt-check lint test ## Run every check CI runs (format, lint, test)

# -----------------------------------------------------------------------------
# Development
# -----------------------------------------------------------------------------
dev: ## Start the full stack locally (Docker Compose)
	docker compose up --build

dev-backend: ## Run the Go backend with hot reload (requires air)
	cd $(BACKEND_DIR) && air

dev-web: ## Start the React web dashboard dev server
	cd $(WEB_DIR) && npm run dev

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
build: ## Build the Go backend binary
	cd $(BACKEND_DIR) && go build -o bin/$(BINARY_NAME) ./cmd/$(BINARY_NAME)

build-web: ## Build the React web dashboard for production
	cd $(WEB_DIR) && npm ci && npm run build

build-docker: ## Build the Docker image for the host architecture
	docker build -f deploy/docker/Dockerfile \
	  --build-arg VERSION=$$(git describe --tags --always --dirty 2>/dev/null || echo dev) \
	  --build-arg REVISION=$$(git rev-parse HEAD) \
	  --build-arg BUILD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
	  -t $(IMAGE) .

build-docker-multiarch: ## Build a multi-arch image (requires buildx)
	docker buildx build -f deploy/docker/Dockerfile \
	  --platform linux/amd64,linux/arm64 \
	  --build-arg VERSION=$$(git describe --tags --always --dirty 2>/dev/null || echo dev) \
	  -t $(IMAGE) .

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------
test: test-backend test-web ## Run all tests (backend + web)

test-backend: ## Run Go tests with the race detector
	cd $(BACKEND_DIR) && go test ./... -race -coverprofile=coverage.out -covermode=atomic

test-web: ## Run web tests
	cd $(WEB_DIR) && npm run test

test-mobile: ## Run Flutter tests (requires flutter)
	cd $(MOBILE_DIR) && flutter test

test-coverage: test-backend ## Run backend tests and open the HTML coverage report
	cd $(BACKEND_DIR) && go tool cover -html=coverage.out

coverage-report: test-backend ## Print backend coverage per function
	cd $(BACKEND_DIR) && go tool cover -func=coverage.out

# -----------------------------------------------------------------------------
# Code quality
# -----------------------------------------------------------------------------
lint: lint-backend lint-web ## Run all linters

lint-backend: ## Run golangci-lint
	cd $(BACKEND_DIR) && golangci-lint run ./...

lint-web: ## Run ESLint on the web dashboard
	cd $(WEB_DIR) && npm run lint

lint-mobile: ## Run flutter analyze (requires flutter)
	cd $(MOBILE_DIR) && flutter analyze

lint-workflows: ## Lint GitHub Actions workflows (requires actionlint)
	actionlint

fmt: ## Format all code in place
	cd $(BACKEND_DIR) && gofmt -s -w . && go run mvdan.cc/gofumpt@v0.11.0 -w .
	cd $(WEB_DIR) && npm run format
	@if command -v dart >/dev/null 2>&1; then cd $(MOBILE_DIR) && dart format .; \
	 else echo "dart not installed; skipping mobile"; fi

fmt-check: ## Fail if any code is not formatted
	@out=$$(cd $(BACKEND_DIR) && gofmt -s -l .); \
	 if [ -n "$$out" ]; then echo "gofmt needed on:"; echo "$$out"; exit 1; fi
	cd $(WEB_DIR) && npm run format:check
	@if command -v dart >/dev/null 2>&1; then cd $(MOBILE_DIR) && dart format --output=none --set-exit-if-changed .; \
	 else echo "dart not installed; skipping mobile"; fi

vet: ## Run go vet
	cd $(BACKEND_DIR) && go vet ./...

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------
# NOTE: cmd/alertdam does not parse subcommands yet, so a `go run ... migrate up`
# target would silently start the HTTP server instead. Apply SQL with psql until
# a real migrate subcommand exists.
migrate-up: ## Apply all migrations with psql
	psql "$${DATABASE_URL:?DATABASE_URL must be set}" -v ON_ERROR_STOP=1 -f $(BACKEND_DIR)/migrations/001_initial.sql

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
docker: ## Start the full stack with Docker Compose (detached)
	docker compose up -d --build

docker-down: ## Stop and remove all containers
	docker compose down

docker-logs: ## Tail logs from all containers
	docker compose logs -f

docker-clean: ## Remove all containers, volumes, and images
	docker compose down -v --rmi local

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
# `gitleaks detect --source` is deprecated in 8.x; `gitleaks git` and
# `gitleaks dir` are the current subcommands.
secrets-scan: ## Scan the full git history for secrets
	gitleaks git . --config .gitleaks.toml --redact --no-banner -v

secrets-scan-files: ## Scan the working tree for secrets
	gitleaks dir . --config .gitleaks.toml --redact --no-banner -v

secrets-scan-staged: ## Scan staged changes only (also runs as a pre-commit hook)
	gitleaks git --staged . --config .gitleaks.toml --redact --no-banner

vuln-scan: ## Scan dependencies for known vulnerabilities
	cd $(BACKEND_DIR) && go run golang.org/x/vuln/cmd/govulncheck@latest ./...
	cd $(WEB_DIR) && npm audit --audit-level=critical

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
setup: hooks tools-backend tools-web ## Install all dev dependencies and git hooks
	@echo ""
	@echo "Setup complete. Run 'make verify' to check everything, or 'make dev' to start."

hooks: ## Install git hooks (lefthook)
	@command -v lefthook >/dev/null 2>&1 || { \
	  echo "Installing lefthook $(LEFTHOOK_VERSION)..."; \
	  if   command -v brew >/dev/null 2>&1; then brew install lefthook; \
	  elif command -v go   >/dev/null 2>&1; then go install github.com/evilmartians/lefthook/v2@v$(LEFTHOOK_VERSION); \
	  elif command -v npm  >/dev/null 2>&1; then npm install -g lefthook@$(LEFTHOOK_VERSION); \
	  else echo "Install lefthook manually: https://lefthook.dev/installation/"; exit 1; fi; }
	lefthook install
	@echo "Git hooks installed. Dry run with: lefthook run pre-commit --all-files"

tools-backend: ## Install Go dev tools
	go install github.com/air-verse/air@latest
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
	go install mvdan.cc/gofumpt@v0.11.0

tools-web: ## Install web dependencies
	cd $(WEB_DIR) && npm ci

tools-mobile: ## Install Flutter dependencies (requires flutter)
	cd $(MOBILE_DIR) && flutter pub get

clean: ## Remove build artifacts
	cd $(BACKEND_DIR) && rm -rf bin/ coverage.out
	cd $(WEB_DIR) && rm -rf dist/ coverage/ node_modules/
	@if command -v flutter >/dev/null 2>&1; then cd $(MOBILE_DIR) && flutter clean; fi

.PHONY: help verify dev dev-backend dev-web build build-web build-docker \
	build-docker-multiarch test test-backend test-web test-mobile test-coverage \
	coverage-report lint lint-backend lint-web lint-mobile lint-workflows fmt \
	fmt-check vet migrate-up docker docker-down docker-logs docker-clean \
	secrets-scan secrets-scan-files secrets-scan-staged vuln-scan setup hooks \
	tools-backend tools-web tools-mobile clean
